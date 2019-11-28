/*
 * fluro
 * Created by Yakka
 * https://theyakka.com
 * 
 * Copyright (c) 2019 Yakka, LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';

import 'package:fluro/fluro.dart';
import 'package:fluro/src/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Router {
  static final appRouter = Router();

  /// The tree structure that stores the defined routes
  final RouteTree _routeTree = RouteTree();

  /// Generic handler for when a route has not been defined
  Handler notFoundHandler;

  /// Creates a [PageRoute] definition for the passed [RouteHandler]. You can optionally provide a default transition type.
  void define(String routePath,
      {@required Handler handler, TransitionType transitionType}) {
    _routeTree.addRoute(
      AppRoute(routePath, handler, transitionType: transitionType),
    );
  }

  /// Finds a defined [AppRoute] for the path value. If no [AppRoute] definition was found
  /// then function will return null.
  AppRouteMatch match(String path) {
    return _routeTree.matchRoute(path);
  }

  bool pop<T extends Object>(BuildContext context, [T result]) =>
      Navigator.pop<T>(context, result);

  ///
  Future<T> navigateTo<T extends Object>(
    BuildContext context,
    String path, {
    Object arguments,
    bool replace = false,
    Object result,
    bool clearStack = false,
    TransitionType transition,
    Duration transitionDuration = const Duration(milliseconds: 300),
    RouteTransitionsBuilder transitionBuilder,
  }) {
    assert(() {
      if (result != null)
        return replace;
      else
        return true;
    }());
    RouteMatch routeMatch = matchRoute(
        context, RouteSettings(name: path, arguments: arguments),
        transitionType: transition,
        transitionsBuilder: transitionBuilder,
        transitionDuration: transitionDuration);
    Completer<T> completer = Completer<T>();

    var route = routeMatch.route;
    var matchType = routeMatch.matchType;
    if (matchType == RouteMatchType.nonVisual) {
      // Non visual route type.
      completer.complete();
    } else {
      if (route != null) {
        if (clearStack) {
          Navigator.pushAndRemoveUntil<T>(context, route, (check) => false)
              .then((value) => completer.complete(value))
              .catchError((error) => completer.completeError(error));
        } else if (replace) {
          Navigator.pushReplacement<T, dynamic>(context, route, result: result)
              .then((value) => completer.complete(value))
              .catchError((error) => completer.completeError(error));
        } else {
          Navigator.push<T>(context, route)
              .then((value) => completer.complete(value))
              .catchError((error) => completer.completeError(error));
        }
      } else {
        String error = "No registered route was found to handle '$path'.";
        print(error);
        completer.completeError(RouteNotFoundException(error, path));
      }
    }

    return completer.future;
  }

  ///
  RouteMatch matchRoute(
    BuildContext context,
    RouteSettings routeSettings, {
    TransitionType transitionType,
    Duration transitionDuration = const Duration(milliseconds: 300),
    RouteTransitionsBuilder transitionsBuilder,
  }) {
    var match = _routeTree.matchRoute(routeSettings.name);
    var route = match?.route;
    var handler = route?.handler ?? notFoundHandler;
    var parameters = match?.parameters;
    var arguments = routeSettings.arguments;
    if (handler == null) {
      return RouteMatch(matchType: RouteMatchType.noMatch);
    } else if (handler.type == HandlerType.function) {
      handler.handlerFunc(context, parameters, arguments);
      return RouteMatch(matchType: RouteMatchType.nonVisual);
    }

    transitionType ??= route?.transitionType ?? TransitionType.native;
    Route creator(
      RouteSettings routeSettings,
      Map<String, List<String>> parameters,
    ) {
      if (transitionType == TransitionType.native) {
        return MaterialPageRoute<dynamic>(
            settings: routeSettings,
            builder: (BuildContext context) {
              return handler.handlerFunc(context, parameters, arguments);
            });
      } else if (transitionType == TransitionType.nativeModal) {
        return MaterialPageRoute<dynamic>(
            settings: routeSettings,
            fullscreenDialog: true,
            builder: (context) {
              return handler.handlerFunc(context, parameters, arguments);
            });
      } else {
        return PageRouteBuilder<dynamic>(
          settings: routeSettings,
          pageBuilder: (context, animation, secondaryAnimation) {
            return handler.handlerFunc(context, parameters, arguments);
          },
          transitionDuration: transitionDuration,
          transitionsBuilder: transitionType == TransitionType.custom
              ? transitionsBuilder
              : _transitionsBuilder(transitionType),
        );
      }
    }

    return RouteMatch(
      matchType: RouteMatchType.visual,
      route: creator(routeSettings, parameters),
    );
  }

  RouteTransitionsBuilder _transitionsBuilder(TransitionType transitionType) {
    return (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) {
      if (transitionType == TransitionType.fadeIn) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
          ),
          child: child,
        );
      } else {
        Animatable<Offset> tween;
        if (transitionType == TransitionType.inFromLeft) {
          tween = Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          );
        } else if (transitionType == TransitionType.inFromRight) {
          tween = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          );
        } else {
          tween = Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          );
        }
        return SlideTransition(
          position: CurvedAnimation(
            parent: animation,
            curve: Curves.linearToEaseOut,
            reverseCurve: Curves.easeInToLinear,
          ).drive(tween),
          child: child,
        );
      }
    };
  }

  /// Route generation method. This function can be used as a way to create routes on-the-fly
  /// if any defined handler is found. It can also be used with the [MaterialApp.onGenerateRoute]
  /// property as callback to create routes that can be used with the [Navigator] class.
  Route<dynamic> generator(RouteSettings routeSettings) {
    RouteMatch match = matchRoute(null, routeSettings);
    return match.route;
  }

  /// Prints the route tree so you can analyze it.
  void printTree() {
    _routeTree.printTree();
  }
}
