import 'dart:async';
import 'dart:io';

import 'package:celest_cli/commands/authenticate.dart';
import 'package:celest_cli/commands/subscriptions/subscription_change_command.dart';
import 'package:celest_cli/src/context.dart';
import 'package:celest_cli_common/celest_cli_common.dart';
import 'package:celest_cloud/celest_cloud.dart'
    show InstanceType, Subscription_State;
import 'package:celest_cloud/src/cloud/subscriptions/subscriptions.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final class SubscribeCommand extends CelestCommand with Authenticate {
  @override
  String get name => 'subscribe';

  @override
  String get category => 'Subscription';

  @override
  String get description => 'Subscribe to Celest Cloud.';

  @override
  Future<int> run() async {
    await super.run();

    final user = await authenticateUser();
    if (user == null) {
      cliLogger.err('You must be signed in to subscribe to Celest Cloud.');
      cliLogger.err('Please run `celest auth login` to sign in.');
      return 1;
    }

    final currentSubscription = await cloud.subscriptions.get(
      'users/${user.userId}/subscription',
    );
    if (currentSubscription != null) {
      cliLogger.success('You are already subscribed to Celest Cloud 🚀');
      return 0;
    }

    final instanceType = cliLogger.chooseOne(
      'Select your instance type:',
      choices: [
        InstanceType.INSTANCE_TYPE_UNSPECIFIED,
        for (final instanceType in InstanceType.values)
          if (instanceType != InstanceType.INSTANCE_TYPE_UNSPECIFIED)
            instanceType,
      ],
      defaultValue: currentSubscription?.builder.instanceType ??
          InstanceType.INSTANCE_TYPE_UNSPECIFIED,
      display: (instanceType) => instanceType.displayString,
    );

    final subscribeCompletion = Completer<void>.sync();
    final server = await shelf_io.serve(
      (request) async {
        if (subscribeCompletion.isCompleted) {
          performance.captureError(
            Exception(
              'Multiple calls to subscription listener: ${request.url}',
            ),
          );
          return Response.internalServerError();
        }
        if (request.url.queryParameters['error'] case final error?) {
          subscribeCompletion.completeError(
            CliException(
              'The subscription could not be completed. '
              'Please contact us before trying again.',
              additionalContext: {'error': error},
            ),
          );
        } else {
          subscribeCompletion.complete();
        }
        return Response.ok(null);
      },
      InternetAddress.anyIPv4,
      0,
    );

    try {
      final response = await cloud.subscriptions.changePlan(
        name: 'users/${user.userId}/subscription',
        plan: switch (instanceType) {
          InstanceType.INSTANCE_TYPE_UNSPECIFIED =>
            const CommunitySubscriptionPlan(),
          final instanceType =>
            BuilderSubscriptionPlan(instanceType: instanceType),
        },
        redirectUri: Uri(
          scheme: 'http',
          host: 'localhost',
          port: server.port,
        ),
      );
      switch (response.subscription.whichState()) {
        case Subscription_State.active:
          break;
        case Subscription_State.paymentRequired:
          var paymentLink = Uri.parse(
            response.subscription.paymentRequired.paymentUri,
          );
          paymentLink = paymentLink.replace(
            queryParameters: {
              ...paymentLink.queryParameters,
              'utm_source': 'cli',
              'utm_medium': 'cli',
              'utm_campaign': 'subscribe',
            },
          );
          logger.finest('Launching payment link: $paymentLink');

          final launchedUrl = await launchUrl(paymentLink);
          if (!launchedUrl) {
            analytics.capture('launch_url_failed');
            cliLogger
              ..info(
                'Please open the following link in your browser to subscribe:',
              )
              ..info(paymentLink.toString());
          } else {
            analytics.capture('launch_url_succeeded');
            cliLogger.info('Please complete the sign up in your browser.');
          }

          await subscribeCompletion.future;
        case Subscription_State.notSet:
          throw StateError('Invalid subscription state (notSet): $response');
        case Subscription_State.canceled:
        case Subscription_State.paused:
        case Subscription_State.suspended:
          throw UnimplementedError();
      }
      cliLogger.success(
        'Your subscription to Celest Cloud was successful! '
        'Welcome aboard! 🚀',
      );
    } finally {
      await server.close(force: true);
    }

    return 0;
  }
}
