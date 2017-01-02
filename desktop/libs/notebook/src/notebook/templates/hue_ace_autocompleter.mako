## Licensed to Cloudera, Inc. under one
## or more contributor license agreements.  See the NOTICE file
## distributed with this work for additional information
## regarding copyright ownership.  Cloudera, Inc. licenses this file
## to you under the Apache License, Version 2.0 (the
## "License"); you may not use this file except in compliance
## with the License.  You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

<%!
from django.utils.translation import ugettext as _
from desktop.views import _ko
%>

<%def name="hueAceAutocompleter()">
  <style>
    .hue-ace-autocompleter {
      position: absolute;
      z-index: 100000;
      width: 500px;
      height: 250px;
      border: 1px solid #DDD;
      display: flex;
      flex-direction: column;

      border-radius: 2px;
      background-color: #FFF;
      -webkit-box-shadow: 0 2px 8px rgba(0,0,0,.18);
      box-shadow: 0 2px 6px 0 rgba(0, 0, 0, 0.18), 0 2px 8px 0 rgba(0, 0, 0, 0.13);
    }

    .autocompleter-header {
      flex: 1 1 30px;
      padding: 5px;
    }

    .autocompleter-list {
      position: relative;
      flex: 1 1 100%;
      overflow-y: auto;
    }

    .autocompleter-list > div {
      height: 19px;
      clear: both;
      background-color: #FFF;
      padding:3px;
    }

    .autocompleter-list > div.selected {
      background-color: #DBE8F1;
    }

  </style>
  <script type="text/html" id="hue-ace-autocompleter">
    <div class="autocompleter-header"><div class="pull-right">header</div></div>
    <div class="autocompleter-list" data-bind="foreach: filteredSuggestions">
      <div data-bind="css: { 'selected': $index() === $parent.selectedIndex() }"><div class="pull-left" data-bind="matchedText: { suggestion: $data, filter: $parent.prefixFilter }"></div><div class="pull-right" data-bind="text: meta"></div></div>
    </div>
    <!-- /ko -->
  </script>

  <script type="text/javascript" charset="utf-8">
    (function () {
      var aceUtil = ace.require("ace/autocomplete/util");
      var HashHandler = ace.require("ace/keyboard/hash_handler").HashHandler;

      ko.bindingHandlers.matchedText = {
        update: function (element, valueAccessor) {
          var options = valueAccessor();
          var $element = $(element);
          $element.empty()
          var suggestion = options.suggestion;
          if (options.filter() && suggestion.matchIndex > -1) {
            var before = suggestion.value.substring(0, suggestion.matchIndex);
            var match = suggestion.value.substring(suggestion.matchIndex, suggestion.matchIndex + suggestion.matchLength);
            var after = suggestion.value.substring(suggestion.matchIndex + suggestion.matchLength);
            $element.append(document.createTextNode(before));
            $('<b>').text(match).appendTo($element);
            $element.append(document.createTextNode(after));
          } else {
            $element.text(suggestion.value);
          }
        }
      };

      function HueAceAutocompleter (params, element) {
        var self = this;
        var snippet = params.snippet;
        var editor = params.editor;

        var autocompleter = new SqlAutocompleter3({ snippet: snippet, timeout: AUTOCOMPLETE_TIMEOUT });
        self.suggestions = autocompleter.autocomplete(editor.getTextBeforeCursor(), editor.getTextAfterCursor());

        var session = editor.getSession();
        var pos = editor.getCursorPosition();

        var line = session.getLine(pos.row);
        var prefix = aceUtil.retrievePrecedingIdentifier(line, pos.column);
        self.base = session.doc.createAnchor(pos.row, pos.column - prefix.length);
        self.base.$insertRight = true;

        self.prefixFilter = ko.observable(prefix.toLowerCase());
        self.activeSuggestions = ko.pureComputed(function () {
          if (self.suggestions.keywords) {
            return self.suggestions.keywords.suggestions();
          }
          return [];
        });

        self.filteredSuggestions = ko.pureComputed(function () {
          if (self.prefixFilter()) {
            var result = self.activeSuggestions().filter(function (suggestion) {
              // TODO: Extend with fuzzy matches
              var foundIndex = suggestion.value.toLowerCase().indexOf(self.prefixFilter());
              if (foundIndex === 0) {
                suggestion.sortWeight = 2;
              } else if (foundIndex > 0) {
                suggestion.sortWeight = 1;
              }
              suggestion.matchIndex = foundIndex;
              suggestion.matchLength = self.prefixFilter().length;
              return suggestion.value.toLowerCase().indexOf(self.prefixFilter()) !== -1;
            });

            result.sort(function (a, b) {
              if (typeof a.sortWeight !== 'undefined' && typeof b.sortWeight !== 'undefined' && b.sortWeight !== a.sortWeight) {
                return b.sortWeight - a.sortWeight;
              }
              if (typeof a.sortWeight !== 'undefined' && typeof b.sortWeight === 'undefined') {
                return -1;
              }
              if (typeof b.sortWeight !== 'undefined' && typeof a.sortWeight === 'undefined') {
                return 1;
              }
              if (typeof a.weight !== 'undefined' && typeof b.weight !== 'undefined' && b.weight !== a.weight) {
                return b.weight - a.weight;
              }
              if (typeof a.weight !== 'undefined' && typeof b.weight === 'undefined') {
                return -1;
              }
              if (typeof b.weight !== 'undefined' && typeof a.weight === 'undefined') {
                return 1;
              }
              return a.value.localeCompare(b.value);
            });
            if (self.selectedIndex() > result.length - 1) {
              self.selectedIndex(result.length === 0 ? 0 : result.length - 1);
            }

            return result;
          }
          return self.activeSuggestions();
        });

        self.selectedIndex = ko.observable(0);

        self.keyboardHandler = new HashHandler();
        self.keyboardHandler.bindKeys({
          "Up": function() {
            if (self.selectedIndex() !== 0) {
              self.selectedIndex(self.selectedIndex() - 1);
            }
            self.scrollSelectionIntoView();
          },
          "Down": function() {
            if (self.selectedIndex() !== self.filteredSuggestions().length - 1) {
              self.selectedIndex(self.selectedIndex() + 1);
            }
            self.scrollSelectionIntoView();
          },
          "Ctrl-Up|Ctrl-Home": function() {
            self.selectedIndex(0);
            self.scrollSelectionIntoView();
          },
          "Ctrl-Down|Ctrl-End": function() {
            self.selectedIndex(self.filteredSuggestions().length - 1);
            self.scrollSelectionIntoView();
          },
          "Esc": function(editor) {
            self.destroy();
          },
          "Return": function(editor) {
            if (self.prefixFilter()) {
              var ranges = editor.selection.getAllRanges();
              for (var i = 0, range; range = ranges[i]; i++) {
                range.start.column -= self.prefixFilter().length;
                editor.session.remove(range);
              }
            }
            editor.execCommand("insertstring", self.filteredSuggestions()[self.selectedIndex()].value);
            editor.renderer.scrollCursorIntoView();
            self.destroy();
          },
          "Shift-Return": function(editor) {
            console.log('insert deleteSuffix');
          },
          "Tab": function(editor) {
            console.log('insert or down if nothing selected');
          },
          "PageUp": function(editor) {
            console.log('page up');
          },
          "PageDown": function(editor) {
            console.log('page down');
          }
        });

        var changeTimeout = -1;

        self.changeListener = function () {
          window.clearTimeout(changeTimeout);
          var cursor = editor.selection.lead;
          if (cursor.row != self.base.row || cursor.column < self.base.column) {
            self.destroy();
          } else {
            changeTimeout = window.setTimeout(function () {
              self.prefixFilter(editor.session.getTextRange({ start: self.base, end: editor.getCursorPosition() }).toLowerCase())
            }, 200);
          }
        };

        self.blurListener = function () {
          console.log('blur');
          //self.destroy();
        };

        self.mousedownListener = function () {
          console.log('mousedown');
        };

        self.mousewheelListener = function () {
          console.log('mousewheel');
        };

        this.destroy = function () {
          self.base.detach();
          window.clearTimeout(changeTimeout);
          editor.keyBinding.removeKeyboardHandler(self.keyboardHandler);
          editor.off("changeSelection", self.changeListener);
          editor.off("blur", self.blurListener);
          editor.off("mousedown", self.mousedownListener);
          editor.off("mousewheel", self.mousewheelListener);
          $(element).remove();
        };

        editor.keyBinding.addKeyboardHandler(self.keyboardHandler);
        editor.on("changeSelection", self.changeListener);
        editor.on("blur", self.blurListener);
        editor.on("mousedown", self.mousedownListener);
        editor.on("mousewheel", self.mousewheelListener);
      }

      HueAceAutocompleter.prototype.scrollSelectionIntoView = function () {
        var self = this;
        var $autocompleterList = $('.autocompleter-list');
        var selected = $autocompleterList.children().eq(self.selectedIndex());
        var selectedTop = selected.position().top;
        if (selectedTop < 0) {
          $autocompleterList.scrollTop($autocompleterList.scrollTop() + selectedTop);
          return;
        }
        var selectedHeight = selected.outerHeight(true);
        var listHeight = $autocompleterList.innerHeight();

        var diff = (selectedHeight + selectedTop) - listHeight;
        if (diff > 0) {
          $autocompleterList.scrollTop($autocompleterList.scrollTop() + diff);
        }
      };

      ko.components.register('hueAceAutocompleter', {
        viewModel: { createViewModel: function (params, componentInfo) {
          return new HueAceAutocompleter(params, componentInfo.element);
        }},
        template: { element: 'hue-ace-autocompleter' }
      });
    })();
  </script>
</%def>
