/*
 * fluro
 * Created by Yakka
 * https://theyakka.com
 * 
 * Copyright (c) 2019 Yakka, LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:flutter/widgets.dart';

///
enum HandlerType {
  route,
  function,
}

///
class Handler {
  final HandlerType type;
  final HandlerFunc handlerFunc;

  Handler({this.type = HandlerType.route, this.handlerFunc});
}

///
typedef HandlerFunc(BuildContext context, Map<String, List<String>> parameters,
    Object arguments);

///
class AppRoute {
  final String route;
  final Handler handler;
  final TransitionType transitionType;

  AppRoute(this.route, this.handler, {this.transitionType});
}

enum TransitionType {
  native,
  nativeModal,
  fadeIn,
  inFromLeft,
  inFromRight,
  inFromBottom,
  custom, // if using custom then you must also provide a transition
}

enum RouteMatchType {
  visual,
  nonVisual,
  noMatch,
}

///
class RouteMatch {
  final Route<dynamic> route;
  final RouteMatchType matchType;
  final String errorMessage;

  RouteMatch({
    this.matchType = RouteMatchType.noMatch,
    this.route,
    this.errorMessage = "Unable to match route. Please check the logs.",
  });
}

class RouteNotFoundException implements Exception {
  final String message;
  final String path;

  RouteNotFoundException(this.message, this.path);

  @override
  String toString() {
    return "No registered route was found to handle '$path'";
  }
}
