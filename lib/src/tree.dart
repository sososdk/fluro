/*
 * fluro
 * Created by Yakka
 * https://theyakka.com
 * 
 * Copyright (c) 2019 Yakka, LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:fluro/src/common.dart';
import 'package:flutter/widgets.dart';

enum RouteTreeNodeType {
  component,
  parameter,
}

class AppRouteMatch {
  final AppRoute route;
  final Map<String, List<String>> parameters;

  AppRouteMatch(this.route, [Map<String, List<String>> parameters])
      : assert(route != null),
        this.parameters = parameters ?? {};
}

class RouteTreeNodeMatch {
  final RouteTreeNode node;
  final Map<String, List<String>> parameters;

  RouteTreeNodeMatch(this.node, [Map<String, List<String>> parameters])
      : assert(node != null),
        this.parameters = parameters ?? {};

  RouteTreeNodeMatch.fromMatch(RouteTreeNodeMatch match, RouteTreeNode node)
      : this(node, match?.parameters);
}

class RouteTreeNode {
  final String part;
  final RouteTreeNodeType type;
  final List<AppRoute> routes;
  final List<RouteTreeNode> nodes;
  final RouteTreeNode parent;

  RouteTreeNode(
    this.part,
    this.type, {
    List<AppRoute> routes,
    List<RouteTreeNode> nodes,
    this.parent,
  })  : this.routes = routes ?? [],
        this.nodes = nodes ?? [];

  bool isParameter() {
    return type == RouteTreeNodeType.parameter;
  }
}

class RouteTree {
  // private
  final _nodes = <RouteTreeNode>[];
  bool _hasDefaultRoute = false;

  // addRoute - add a route to the route tree
  void addRoute(AppRoute route) {
    var path = route.route;
    // is root/default route, just add it
    if (path == Navigator.defaultRouteName) {
      if (_hasDefaultRoute) {
        // throw an error because the internal consistency of the router
        // could be affected
        throw ("Default route was already defined");
      }
      var node =
          RouteTreeNode(path, RouteTreeNodeType.component, routes: [route]);
      _nodes.add(node);
      _hasDefaultRoute = true;
      return;
    }
    if (path.startsWith("/")) {
      path = path.substring(1);
    }
    var pathComponents = path.split('/');
    RouteTreeNode parent;
    for (int i = 0; i < pathComponents.length; i++) {
      var component = pathComponents[i];
      var node = _nodeForComponent(component, parent);
      if (node == null) {
        node = RouteTreeNode(component, _typeForComponent(component),
            parent: parent);
        if (parent == null) {
          _nodes.add(node);
        } else {
          parent.nodes.add(node);
        }
      }
      if (i == pathComponents.length - 1) {
        node.routes.add(route);
      }
      parent = node;
    }
  }

  AppRouteMatch matchRoute(String path) {
    var usePath = path;
    if (usePath.startsWith("/")) {
      usePath = path.substring(1);
    }
    var components = usePath.split("/");
    if (path == Navigator.defaultRouteName) {
      components = ["/"];
    }

    var nodeMatches = <RouteTreeNode, RouteTreeNodeMatch>{};
    var nodesToCheck = _nodes;
    for (String checkComponent in components) {
      var currentMatches = <RouteTreeNode, RouteTreeNodeMatch>{};
      var nextNodes = <RouteTreeNode>[];
      for (RouteTreeNode node in nodesToCheck) {
        var pathPart = checkComponent;
        Map<String, List<String>> queryMap;
        if (checkComponent.contains("?")) {
          var splitParam = checkComponent.split("?");
          pathPart = splitParam[0];
          queryMap = parseQueryString(splitParam[1]);
        }
        var isMatch = (node.part == pathPart || node.isParameter());
        if (isMatch) {
          var parentMatch = nodeMatches[node.parent];
          var match = RouteTreeNodeMatch.fromMatch(parentMatch, node);
          if (node.isParameter()) {
            var paramKey = node.part.substring(1);
            match.parameters[paramKey] = [pathPart];
          }
          if (queryMap != null) {
            match.parameters.addAll(queryMap);
          }
          currentMatches[node] = match;
          if (node.nodes != null) {
            nextNodes.addAll(node.nodes);
          }
        }
      }
      nodeMatches = currentMatches;
      nodesToCheck = nextNodes;
      if (currentMatches.values.length == 0) {
        return null;
      }
    }
    var matches = nodeMatches.values.toList();
    if (matches.length > 0) {
      var match = matches.first;
      var nodeToUse = match.node;
      if ((nodeToUse?.routes?.length ?? 0) > 0) {
        return AppRouteMatch(nodeToUse.routes[0], match.parameters);
      }
    }
    return null;
  }

  void printTree() {
    _printSubTree();
  }

  void _printSubTree({RouteTreeNode parent, int level = 0}) {
    var nodes = parent != null ? parent.nodes : _nodes;
    for (RouteTreeNode node in nodes) {
      var indent = "";
      for (int i = 0; i < level; i++) {
        indent += "    ";
      }
      print("$indent${node.part}: total routes=${node.routes.length}");
      if (node.nodes != null && node.nodes.length > 0) {
        _printSubTree(parent: node, level: level + 1);
      }
    }
  }

  RouteTreeNode _nodeForComponent(String component, RouteTreeNode parent) {
    var nodes = _nodes;
    if (parent != null) {
      // search parent for sub-node matches
      nodes = parent.nodes;
    }
    for (RouteTreeNode node in nodes) {
      if (node.part == component) {
        return node;
      }
    }
    return null;
  }

  RouteTreeNodeType _typeForComponent(String component) {
    var type = RouteTreeNodeType.component;
    if (_isParameterComponent(component)) {
      type = RouteTreeNodeType.parameter;
    }
    return type;
  }

  /// Is the path component a parameter
  bool _isParameterComponent(String component) {
    return component.startsWith(":");
  }

  Map<String, List<String>> parseQueryString(String query) {
    var search = RegExp('([^&=]+)=?([^&]*)');
    var params = Map<String, List<String>>();
    if (query.startsWith('?')) query = query.substring(1);
    String decode(String s) => Uri.decodeComponent(s.replaceAll('+', ' '));
    for (Match match in search.allMatches(query)) {
      var key = decode(match.group(1));
      var value = decode(match.group(2));
      if (params.containsKey(key)) {
        params[key].add(value);
      } else {
        params[key] = [value];
      }
    }
    return params;
  }
}
