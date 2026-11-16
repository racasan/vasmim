import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../canvas/foreground_item_style.dart';
import 'note.dart';
import 'note_color_palette.dart';
import 'note_emphasis.dart';
import 'note_list_transform.dart';
import 'note_markdown_import.dart';
import 'note_text_link.dart';
import 'note_multi_website_body.dart';
import 'note_website_body.dart';

class EditableNote extends StatefulWidget {
  const EditableNote({
    required this.note,
    required this.isSelected,
    required this.isEditing,
    required this.onSelect,
    required this.onEditTitle,
    required this.onSecondaryTapDown,
    required this.onBeginEditing,
    required this.onEndEditing,
    required this.onBeginMoving,
    required this.onMove,
    required this.onEndMoving,
    required this.onBeginResizing,
    required this.onResize,
    required this.onEndResizing,
    required this.onTextChanged,
    required this.onEmphasisChanged,
    required this.onLinksChanged,
    required this.onOpenLink,
    this.websiteMarker,
    this.websiteHost,
    this.multiWebsiteLinkCount,
    this.showInteractionChrome = true,
    super.key,
  });

  static const double headerHeight = 42;
  static const double resizeRailHeight = 22;

  final Note note;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onSelect;
  final VoidCallback onEditTitle;
  final GestureTapDownCallback onSecondaryTapDown;
  final VoidCallback onBeginEditing;
  final VoidCallback onEndEditing;
  final ValueChanged<Offset> onBeginMoving;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEndMoving;
  final ValueChanged<Offset> onBeginResizing;
  final ValueChanged<Offset> onResize;
  final VoidCallback onEndResizing;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<List<NoteEmphasisRange>> onEmphasisChanged;
  final ValueChanged<List<NoteTextLinkRange>> onLinksChanged;
  final Future<void> Function(Uri url) onOpenLink;
  final Widget? websiteMarker;
  final String? websiteHost;
  final int? multiWebsiteLinkCount;
  final bool showInteractionChrome;

  @override
  State<EditableNote> createState() => _EditableNoteState();
}

class _EditableNoteState extends State<EditableNote> {
  late final _NoteTextEditingController _textController;
  late final UndoHistoryController _textUndoController;
  late final FocusNode _textFocusNode;
  late final ScrollController _textScrollController;
  Offset? _movePointerDownPosition;
  Offset? _resizePointerDownPosition;
  bool _isResizeRailHovered = false;
  final List<_NotePresentationSnapshot> _presentationUndoStack = [];
  final List<_NotePresentationSnapshot> _presentationRedoStack = [];
  final GlobalKey<TooltipState> _linkTooltipKey = GlobalKey<TooltipState>();
  _PendingLinkActivation? _pendingLinkActivation;
  NoteTextLinkRange? _hoveredTextLink;
  Timer? _linkTooltipTimer;
  Timer? _titleDoubleTapTimer;
  bool _suppressNextTextTap = false;

  @override
  void initState() {
    super.initState();
    _textController = _NoteTextEditingController(
      text: widget.note.text,
      emphasis: widget.note.emphasis,
      links: widget.note.links,
    );
    _textUndoController = UndoHistoryController();
    _textUndoController.onUndo.addListener(_textController.prepareUndo);
    _textUndoController.onRedo.addListener(_textController.prepareRedo);
    _textFocusNode = FocusNode();
    _textScrollController = ScrollController();
    HardwareKeyboard.instance.addHandler(_handleTextKeyEvent);
    if (widget.isEditing) {
      _requestTextFocus();
    }
  }

  @override
  void didUpdateWidget(covariant EditableNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_textController.text != widget.note.text ||
        !_emphasisRangesEqual(_textController.emphasis, widget.note.emphasis) ||
        !_linkRangesEqual(_textController.links, widget.note.links)) {
      _textController.replaceFromModel(
        text: widget.note.text,
        emphasis: widget.note.emphasis,
        links: widget.note.links,
      );
    }
    if (!oldWidget.isEditing && widget.isEditing) {
      _requestTextFocus();
    } else if (oldWidget.isEditing && !widget.isEditing) {
      _textFocusNode.unfocus();
    }
  }

  void _requestTextFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isEditing) {
        _textFocusNode.requestFocus();
      }
    });
  }

  void _handleHeaderTap() {
    widget.onSelect();
    if (_titleDoubleTapTimer?.isActive ?? false) {
      _titleDoubleTapTimer!.cancel();
      _titleDoubleTapTimer = null;
      widget.onEditTitle();
      return;
    }
    _titleDoubleTapTimer = Timer(kDoubleTapTimeout, () {
      _titleDoubleTapTimer = null;
    });
  }

  void _beginEditingAt(Offset globalPosition) {
    widget.onBeginEditing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isEditing) {
        return;
      }
      final renderEditable = _findRenderEditable(context.findRenderObject());
      if (renderEditable == null) {
        return;
      }
      final position = renderEditable.getPositionForPoint(globalPosition);
      _textController.selection = TextSelection.collapsed(
        offset: position.offset.clamp(0, _textController.text.length),
        affinity: position.affinity,
      );
    });
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root is RenderEditable) {
      return root;
    }
    RenderEditable? result;
    root?.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  void _handleTextPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (
      resolvedEvent,
    ) {
      if (!_textScrollController.hasClients) {
        return;
      }
      final scrollEvent = resolvedEvent as PointerScrollEvent;
      final position = _textScrollController.position;
      final target = (position.pixels + scrollEvent.scrollDelta.dy)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (target != position.pixels) {
        _textScrollController.jumpTo(target);
      }
    });
  }

  void _prepareLinkActivation(PointerDownEvent event) {
    _pendingLinkActivation = null;
    _suppressNextTextTap = false;
    final keyboard = HardwareKeyboard.instance;
    if (event.buttons & kPrimaryMouseButton == 0 ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        (widget.isEditing && !keyboard.isControlPressed)) {
      return;
    }
    final link = _textLinkAtGlobalPosition(event.position);
    if (link != null) {
      _suppressNextTextTap = true;
      _pendingLinkActivation = _PendingLinkActivation(
        link: link,
        selection: _textController.selection,
        position: event.position,
      );
    }
  }

  NoteTextLinkRange? _textLinkAtGlobalPosition(Offset globalPosition) {
    final renderEditable = _findRenderEditable(context.findRenderObject());
    if (renderEditable == null) {
      return null;
    }
    final offset = renderEditable
        .getPositionForPoint(globalPosition)
        .offset
        .clamp(0, _textController.text.length);
    return NoteTextLinks.linkAt(_textController.links, offset);
  }

  void _handleTextHover(PointerHoverEvent event) {
    final link = _textLinkAtGlobalPosition(event.position);
    if (link == _hoveredTextLink) {
      return;
    }
    _linkTooltipTimer?.cancel();
    Tooltip.dismissAllToolTips();
    setState(() => _hoveredTextLink = link);
    if (link != null) {
      _linkTooltipTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _hoveredTextLink != link) {
          return;
        }
        _linkTooltipKey.currentState?.ensureTooltipVisible();
      });
    }
  }

  void _clearTextLinkHover() {
    _linkTooltipTimer?.cancel();
    _linkTooltipTimer = null;
    if (_hoveredTextLink == null) {
      return;
    }
    Tooltip.dismissAllToolTips();
    setState(() => _hoveredTextLink = null);
  }

  void _completeLinkActivation(PointerUpEvent event) {
    final pending = _pendingLinkActivation;
    _pendingLinkActivation = null;
    if (pending == null || (event.position - pending.position).distance > 4) {
      return;
    }
    unawaited(widget.onOpenLink(pending.link.uri));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isEditing) {
        _textController.selection = pending.selection;
        _textFocusNode.requestFocus();
      }
    });
  }

  void _handleTextTap() {
    if (_suppressNextTextTap) {
      _suppressNextTextTap = false;
      return;
    }
    widget.onBeginEditing();
  }

  bool _handleTextKeyEvent(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!widget.isEditing ||
        !_textFocusNode.hasFocus ||
        event is! KeyDownEvent) {
      return false;
    }
    if (!keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyB &&
        !keyboard.isShiftPressed) {
      return _toggleEmphasis(NoteEmphasisStyle.bold);
    }
    if (event.logicalKey == LogicalKeyboardKey.keyU &&
        !keyboard.isShiftPressed) {
      return _toggleEmphasis(NoteEmphasisStyle.underline);
    }
    if (event.logicalKey == LogicalKeyboardKey.keyI &&
        !keyboard.isShiftPressed) {
      return _toggleEmphasis(NoteEmphasisStyle.italic);
    }
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        !keyboard.isShiftPressed) {
      return _editSelectedTextLink();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        !keyboard.isShiftPressed &&
        _presentationUndoStack.isNotEmpty) {
      _undoPresentation();
      return true;
    }
    if ((event.logicalKey == LogicalKeyboardKey.keyY &&
            !keyboard.isShiftPressed) ||
        (event.logicalKey == LogicalKeyboardKey.keyZ &&
            keyboard.isShiftPressed)) {
      if (_presentationRedoStack.isNotEmpty) {
        _redoPresentation();
      } else {
        _textUndoController.redo();
      }
      return true;
    }
    return false;
  }

  bool _insertNewline() {
    final selection = _textController.selection;
    final focusContext = _textFocusNode.context;
    if (!selection.isValid || focusContext == null) {
      return false;
    }
    Actions.invoke(
      focusContext,
      ReplaceTextIntent(
        _textController.value,
        '\n',
        selection,
        SelectionChangedCause.keyboard,
      ),
    );
    return true;
  }

  bool _toggleEmphasis(NoteEmphasisStyle style) {
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return false;
    }
    final start = selection.start;
    final end = selection.end;
    final next = NoteEmphasis.toggle(
      textLength: _textController.text.length,
      ranges: _textController.emphasis,
      start: start,
      end: end,
      style: style,
    );
    _recordPresentationChange();
    _applyEmphasis(next);
    return true;
  }

  bool _toggleList(NoteListStyle style) {
    final transformation = NoteListTransformer.toggle(
      text: _textController.text,
      selection: _textController.selection,
      emphasis: _textController.emphasis,
      links: _textController.links,
      style: style,
    );
    if (transformation == null) return false;

    _presentationUndoStack.clear();
    _presentationRedoStack.clear();
    _textController.applyStructuredEdit(transformation);
    widget.onTextChanged(transformation.text);
    widget.onEmphasisChanged(transformation.emphasis);
    widget.onLinksChanged(transformation.links);
    return true;
  }

  void _recordPresentationChange() {
    _presentationUndoStack.add(
      _NotePresentationSnapshot(
        emphasis: _textController.emphasis,
        links: _textController.links,
      ),
    );
    _presentationRedoStack.clear();
  }

  void _undoPresentation() {
    _presentationRedoStack.add(
      _NotePresentationSnapshot(
        emphasis: _textController.emphasis,
        links: _textController.links,
      ),
    );
    _applyPresentation(_presentationUndoStack.removeLast());
  }

  void _redoPresentation() {
    _presentationUndoStack.add(
      _NotePresentationSnapshot(
        emphasis: _textController.emphasis,
        links: _textController.links,
      ),
    );
    _applyPresentation(_presentationRedoStack.removeLast());
  }

  void _applyPresentation(_NotePresentationSnapshot snapshot) {
    _textController.updatePresentation(
      emphasis: snapshot.emphasis,
      links: snapshot.links,
    );
    widget.onEmphasisChanged(snapshot.emphasis);
    widget.onLinksChanged(snapshot.links);
  }

  void _applyEmphasis(List<NoteEmphasisRange> emphasis) {
    _textController.updatePresentation(
      emphasis: emphasis,
      links: _textController.links,
    );
    widget.onEmphasisChanged(emphasis);
  }

  void _handleTextChanged(String text) {
    _presentationUndoStack.clear();
    _presentationRedoStack.clear();
    widget.onTextChanged(text);
    widget.onEmphasisChanged(_textController.emphasis);
    widget.onLinksChanged(_textController.links);
  }

  bool _editSelectedTextLink() {
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return false;
    }
    final existing = NoteTextLinks.singleIntersecting(
      _textController.links,
      selection.start,
      selection.end,
    );
    if (existing == null &&
        !NoteTextLinks.canAdd(
          _textController.links,
          selection.start,
          selection.end,
        )) {
      return false;
    }
    unawaited(
      _showTextLinkDialog(
        start: selection.start,
        end: selection.end,
        existing: existing,
      ),
    );
    return true;
  }

  Future<void> _showTextLinkDialog({
    required int start,
    required int end,
    required NoteTextLinkRange? existing,
  }) async {
    final sourceText = _textController.text;
    var rawDestination = existing?.destination ?? '';
    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? validationMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final normalized = NoteTextLinks.normalizeDestination(
                rawDestination,
              );
              if (normalized == null) {
                setDialogState(() {
                  validationMessage =
                      'Enter a complete http or https website address.';
                });
                return;
              }
              Navigator.of(dialogContext).pop(normalized);
            }

            return AlertDialog(
              title: Text(existing == null ? 'Add link' : 'Edit link'),
              content: SizedBox(
                width: 420,
                child: TextFormField(
                  key: const ValueKey('note-text-link-destination-field'),
                  initialValue: rawDestination,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Website address',
                    hintText: 'https://example.com',
                    errorText: validationMessage,
                  ),
                  onChanged: (value) => rawDestination = value,
                  onFieldSubmitted: (_) => submit(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('note-text-link-save'),
                  onPressed: submit,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || _textController.text != sourceText) {
      return;
    }
    widget.onBeginEditing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isEditing) {
        return;
      }
      _textController.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
      _textFocusNode.requestFocus();
    });
    if (destination == null) {
      return;
    }
    if (existing != null && existing.destination == destination) {
      return;
    }
    final next = existing == null
        ? NoteTextLinks.add(
            textLength: sourceText.length,
            ranges: _textController.links,
            start: start,
            end: end,
            destination: destination,
          )
        : NoteTextLinks.replace(
            ranges: _textController.links,
            target: existing,
            destination: destination,
          );
    _recordPresentationChange();
    _applyLinks(next);
  }

  void _applyLinks(List<NoteTextLinkRange> links) {
    _textController.updatePresentation(
      emphasis: _textController.emphasis,
      links: links,
    );
    widget.onLinksChanged(links);
  }

  void _removeSelectedTextLink(NoteTextLinkRange link) {
    _recordPresentationChange();
    _applyLinks(NoteTextLinks.remove(_textController.links, link));
  }

  void _openSelectedTextLink(NoteTextLinkRange link) {
    unawaited(widget.onOpenLink(link.uri));
  }

  Widget _buildTextContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = List<ContextMenuButtonItem>.of(
      editableTextState.contextMenuButtonItems,
    );
    final selection = _textController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedLink = NoteTextLinks.singleIntersecting(
        _textController.links,
        selection.start,
        selection.end,
      );
      final canAddLink =
          selectedLink == null &&
          NoteTextLinks.canAdd(
            _textController.links,
            selection.start,
            selection.end,
          );
      final emphasisItems = [
        ContextMenuButtonItem(
          label: 'Bold',
          onPressed: () {
            editableTextState.hideToolbar();
            _toggleEmphasis(NoteEmphasisStyle.bold);
          },
        ),
        ContextMenuButtonItem(
          label: 'Underline',
          onPressed: () {
            editableTextState.hideToolbar();
            _toggleEmphasis(NoteEmphasisStyle.underline);
          },
        ),
        ContextMenuButtonItem(
          label: 'Italic',
          onPressed: () {
            editableTextState.hideToolbar();
            _toggleEmphasis(NoteEmphasisStyle.italic);
          },
        ),
      ];
      if (selectedLink != null) {
        items.insertAll(0, [
          ContextMenuButtonItem(
            label: 'Edit link...',
            onPressed: () {
              editableTextState.hideToolbar();
              unawaited(
                _showTextLinkDialog(
                  start: selection.start,
                  end: selection.end,
                  existing: selectedLink,
                ),
              );
            },
          ),
          ContextMenuButtonItem(
            label: 'Remove link',
            onPressed: () {
              editableTextState.hideToolbar();
              _removeSelectedTextLink(selectedLink);
            },
          ),
          ContextMenuButtonItem(
            label: 'Open link',
            onPressed: () {
              editableTextState.hideToolbar();
              _openSelectedTextLink(selectedLink);
            },
          ),
        ]);
      }
      items.addAll(emphasisItems);
      items.addAll([
        ContextMenuButtonItem(
          label: 'Bulleted list',
          onPressed: () {
            editableTextState.hideToolbar();
            _toggleList(NoteListStyle.bulleted);
          },
        ),
        ContextMenuButtonItem(
          label: 'Numbered list',
          onPressed: () {
            editableTextState.hideToolbar();
            _toggleList(NoteListStyle.numbered);
          },
        ),
      ]);
      if (canAddLink) {
        items.add(
          ContextMenuButtonItem(
            label: 'Add link...',
            onPressed: () {
              editableTextState.hideToolbar();
              _editSelectedTextLink();
            },
          ),
        );
      }
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  void dispose() {
    _linkTooltipTimer?.cancel();
    _titleDoubleTapTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleTextKeyEvent);
    _textUndoController.onUndo.removeListener(_textController.prepareUndo);
    _textUndoController.onRedo.removeListener(_textController.prepareRedo);
    _textFocusNode.dispose();
    _textScrollController.dispose();
    _textUndoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = widget.isEditing
        ? colorScheme.tertiary
        : widget.isSelected
        ? colorScheme.primary
        : widget.note.color.borderColor;

    return Semantics(
      label: 'Editable note',
      child: AnimatedContainer(
        key: ValueKey('note-container-${widget.note.id}'),
        duration: const Duration(milliseconds: 120),
        width: widget.note.width,
        height: widget.note.height,
        decoration: BoxDecoration(
          color: widget.note.color.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: ForegroundItemStyle.shadows,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Listener(
                    onPointerDown: (event) =>
                        _movePointerDownPosition = event.position,
                    onPointerCancel: (_) => widget.onEndMoving(),
                    child: GestureDetector(
                      key: ValueKey('note-drag-handle-${widget.note.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleHeaderTap,
                      onSecondaryTapDown: widget.onSecondaryTapDown,
                      onPanStart: (details) => widget.onBeginMoving(
                        _movePointerDownPosition ?? details.globalPosition,
                      ),
                      onPanUpdate: (details) =>
                          widget.onMove(details.globalPosition),
                      onPanEnd: (_) => widget.onEndMoving(),
                      onPanCancel: widget.onEndMoving,
                      child: Container(
                        height: EditableNote.headerHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.note.color.headerColor,
                          border: Border(
                            bottom: BorderSide(
                              color: widget.note.color.borderColor,
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (widget.showInteractionChrome) ...[
                              Icon(
                                Icons.drag_indicator,
                                size: 18,
                                color: borderColor,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Tooltip(
                                message: widget.note.title ?? 'Drag to move',
                                child: Text(
                                  widget.note.title ??
                                      (widget.showInteractionChrome
                                          ? 'DRAG TO MOVE'
                                          : ''),
                                  key: ValueKey('note-title-${widget.note.id}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: borderColor,
                                    fontSize: widget.note.title == null
                                        ? 10
                                        : 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: widget.note.title == null
                                        ? 0.8
                                        : 0.1,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.websiteMarker case final marker?) ...[
                              SizedBox.square(dimension: 22, child: marker),
                              const SizedBox(width: 8),
                            ],
                            if (widget.showInteractionChrome &&
                                (widget.isEditing || widget.isSelected))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.isEditing ? 'EDITING' : 'SELECTED',
                                  style: TextStyle(
                                    color: borderColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildBody()),
                if (widget.showInteractionChrome)
                  _buildResizeRail(colorScheme, borderColor)
                else
                  SizedBox(
                    height: EditableNote.resizeRailHeight,
                    child: ColoredBox(color: widget.note.color.backgroundColor),
                  ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: ValueKey('note-border-${widget.note.id}'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: borderColor,
                      width: widget.isSelected || widget.isEditing ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeRail(ColorScheme colorScheme, Color borderColor) {
    final isActive = widget.isSelected || _isResizeRailHovered;
    final railColor = Color.alphaBlend(
      (isActive ? colorScheme.primary : widget.note.color.borderColor)
          .withValues(alpha: isActive ? 0.16 : 0.08),
      widget.note.color.backgroundColor,
    );
    final cueColor = isActive
        ? colorScheme.primary
        : widget.note.color.borderColor.withValues(alpha: 0.72);
    return MouseRegion(
      key: ValueKey('note-resize-rail-region-${widget.note.id}'),
      cursor: SystemMouseCursors.resizeUpLeftDownRight,
      onEnter: (_) => setState(() => _isResizeRailHovered = true),
      onExit: (_) => setState(() => _isResizeRailHovered = false),
      child: Tooltip(
        message: 'Resize note',
        child: Listener(
          onPointerDown: (event) {
            if (event.buttons & kPrimaryMouseButton != 0) {
              _resizePointerDownPosition = event.position;
            }
          },
          onPointerUp: (_) => _resizePointerDownPosition = null,
          onPointerCancel: (_) => _resizePointerDownPosition = null,
          child: GestureDetector(
            key: ValueKey('note-resize-handle-${widget.note.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            onSecondaryTapDown: widget.onSecondaryTapDown,
            onPanStart: (details) => widget.onBeginResizing(
              _resizePointerDownPosition ?? details.globalPosition,
            ),
            onPanUpdate: (details) => widget.onResize(details.globalPosition),
            onPanEnd: (_) {
              _resizePointerDownPosition = null;
              widget.onEndResizing();
            },
            onPanCancel: () {
              _resizePointerDownPosition = null;
              widget.onEndResizing();
            },
            child: AnimatedContainer(
              key: ValueKey('note-resize-rail-${widget.note.id}'),
              duration: const Duration(milliseconds: 120),
              height: EditableNote.resizeRailHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: railColor,
                border: Border(top: BorderSide(color: borderColor, width: 1)),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(7),
                ),
              ),
              alignment: Alignment.centerRight,
              child: Icon(Icons.open_in_full, size: 14, color: cueColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final scrollbarTheme = ScrollbarTheme.of(context);
    final textEditor = ScrollbarTheme(
      key: ValueKey('note-text-scrollbar-theme-${widget.note.id}'),
      data: scrollbarTheme.copyWith(
        thumbVisibility: WidgetStatePropertyAll(widget.showInteractionChrome),
        thickness: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? 12
              : 9;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final alpha =
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? 0.72
              : 0.46;
          return widget.note.color.borderColor.withValues(alpha: alpha);
        }),
        radius: const Radius.circular(6),
        crossAxisMargin: 3,
        mainAxisMargin: 4,
      ),
      child: Scrollbar(
        key: ValueKey('note-text-scrollbar-${widget.note.id}'),
        controller: _textScrollController,
        thumbVisibility: widget.showInteractionChrome,
        interactive: widget.showInteractionChrome,
        child: Padding(
          key: ValueKey('note-text-content-padding-${widget.note.id}'),
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            18,
            widget.websiteHost == null && widget.multiWebsiteLinkCount == null
                ? 14
                : 8,
          ),
          child: ScrollbarTheme(
            data: scrollbarTheme.copyWith(
              thumbVisibility: const WidgetStatePropertyAll(false),
              thickness: const WidgetStatePropertyAll(0),
              thumbColor: const WidgetStatePropertyAll(Colors.transparent),
              trackColor: const WidgetStatePropertyAll(Colors.transparent),
              trackBorderColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              interactive: false,
            ),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _insertNewline,
                const SingleActivator(LogicalKeyboardKey.numpadEnter):
                    _insertNewline,
              },
              child: TextField(
                key: ValueKey('note-text-field-${widget.note.id}'),
                controller: _textController,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    _textController.formatMarkdownEdit,
                  ),
                ],
                undoController: _textUndoController,
                focusNode: _textFocusNode,
                scrollController: _textScrollController,
                mouseCursor: _hoveredTextLink == null
                    ? SystemMouseCursors.text
                    : SystemMouseCursors.click,
                readOnly: !widget.isEditing,
                showCursor: widget.isEditing,
                enableInteractiveSelection: widget.isEditing,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                expands: true,
                maxLines: null,
                onTap: _handleTextTap,
                onChanged: _handleTextChanged,
                contextMenuBuilder: _buildTextContextMenu,
                onTapOutside: (event) {
                  if (event.buttons & kSecondaryMouseButton == 0) {
                    widget.onEndEditing();
                  }
                },
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  color: Color(0xFF242424),
                  fontSize: 18,
                  height: 1.3,
                ),
                decoration: InputDecoration.collapsed(
                  hintText: widget.showInteractionChrome
                      ? 'Click to edit this note'
                      : null,
                  hintStyle: const TextStyle(color: Color(0xFF5D5D5D)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final websiteHost = widget.websiteHost;
    final multiWebsiteLinkCount = widget.multiWebsiteLinkCount;
    final body = websiteHost != null
        ? NoteWebsiteBody(
            key: ValueKey('note-website-body-${widget.note.id}'),
            host: websiteHost,
            accentColor: widget.note.color.borderColor,
            child: textEditor,
          )
        : multiWebsiteLinkCount != null
        ? NoteMultiWebsiteBody(
            key: ValueKey('note-multi-website-body-${widget.note.id}'),
            linkCount: multiWebsiteLinkCount,
            accentColor: widget.note.color.borderColor,
            child: textEditor,
          )
        : textEditor;
    final hoveredLink = _hoveredTextLink;
    return MouseRegion(
      key: ValueKey('note-text-link-region-${widget.note.id}'),
      cursor: hoveredLink == null
          ? SystemMouseCursors.text
          : SystemMouseCursors.click,
      onHover: _handleTextHover,
      onExit: (_) => _clearTextLinkHover(),
      child: Tooltip(
        key: _linkTooltipKey,
        message: hoveredLink == null
            ? ''
            : '${hoveredLink.uri.host}\n'
                  '${widget.isEditing ? 'Ctrl+click' : 'Click'} to open',
        triggerMode: TooltipTriggerMode.manual,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: _handleTextPointerSignal,
          onPointerDown: (event) {
            _prepareLinkActivation(event);
            if (!widget.isEditing &&
                event.buttons & kSecondaryMouseButton != 0) {
              widget.onSecondaryTapDown(
                TapDownDetails(
                  globalPosition: event.position,
                  kind: event.kind,
                ),
              );
            } else if (!widget.isEditing &&
                event.buttons & kPrimaryMouseButton != 0 &&
                _pendingLinkActivation == null) {
              _beginEditingAt(event.position);
            }
          },
          onPointerUp: _completeLinkActivation,
          onPointerCancel: (_) {
            _pendingLinkActivation = null;
            _suppressNextTextTap = false;
          },
          child: body,
        ),
      ),
    );
  }
}

class _NoteTextEditingController extends TextEditingController {
  _NoteTextEditingController({
    required String text,
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
  }) : _emphasis = List.unmodifiable(emphasis),
       _links = List.unmodifiable(links),
       super(text: text);

  List<NoteEmphasisRange> _emphasis;
  List<NoteTextLinkRange> _links;
  bool _replacingFromModel = false;
  _TextHistoryDirection? _historyDirection;
  final List<_TextPresentationSnapshot> _past = [];
  final List<_TextPresentationSnapshot> _future = [];
  final List<({String before, String after})> _structuredTransitions = [];
  ({String text, int start, NoteMarkdownImport imported})? _pendingMarkdown;

  List<NoteEmphasisRange> get emphasis => _emphasis;
  List<NoteTextLinkRange> get links => _links;

  // Format user input before EditableText records its selection and undo value.
  // Model replacement and undo must never parse Markdown again.
  TextEditingValue formatMarkdownEdit(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    _pendingMarkdown = null;
    if (!_replacingFromModel &&
        _historyDirection == null &&
        newValue.text != oldValue.text &&
        newValue.composing.isCollapsed) {
      final oldText = oldValue.text;
      final rawText = newValue.text;
      var prefix = 0;
      while (prefix < oldText.length &&
          prefix < rawText.length &&
          oldText.codeUnitAt(prefix) == rawText.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < oldText.length - prefix &&
          suffix < rawText.length - prefix &&
          oldText.codeUnitAt(oldText.length - suffix - 1) ==
              rawText.codeUnitAt(rawText.length - suffix - 1)) {
        suffix++;
      }
      final inserted = rawText.substring(prefix, rawText.length - suffix);
      if (inserted.length > 1 &&
          NoteMarkdownImport.looksLikeMarkdown(inserted)) {
        final imported = NoteMarkdownImport.parse(inserted);
        final replacement = imported.text;
        final converted = rawText.replaceRange(
          prefix,
          rawText.length - suffix,
          replacement,
        );
        final removedLength = inserted.length - replacement.length;
        int adjust(int offset) {
          if (offset < 0 || offset <= prefix) return offset;
          if (offset >= rawText.length - suffix) return offset - removedLength;
          return prefix + (offset - prefix).clamp(0, replacement.length);
        }

        newValue = newValue.copyWith(
          text: converted,
          selection: TextSelection(
            baseOffset: adjust(newValue.selection.baseOffset),
            extentOffset: adjust(newValue.selection.extentOffset),
          ),
          composing: TextRange.empty,
        );
        _pendingMarkdown = (text: converted, start: prefix, imported: imported);
      }
    }
    return newValue;
  }

  @override
  set value(TextEditingValue newValue) {
    final pending = _pendingMarkdown;
    _pendingMarkdown = null;
    final imported = pending?.text == newValue.text ? pending?.imported : null;
    final insertionStart = pending?.start ?? 0;
    if (!_replacingFromModel && newValue.text != value.text) {
      final current = _TextPresentationSnapshot(
        text: value.text,
        emphasis: _emphasis,
        links: _links,
      );
      final restored = switch (_historyDirection) {
        _TextHistoryDirection.undo => _restoreMatching(
          source: _past,
          destination: _future,
          current: current,
          targetText: newValue.text,
        ),
        _TextHistoryDirection.redo => _restoreMatching(
          source: _future,
          destination: _past,
          current: current,
          targetText: newValue.text,
        ),
        null
            when _structuredTransitions.any(
              (transition) =>
                  transition.after == value.text &&
                  transition.before == newValue.text,
            ) =>
          _restoreMatching(
            source: _past,
            destination: _future,
            current: current,
            targetText: newValue.text,
          ),
        null
            when _structuredTransitions.any(
              (transition) =>
                  transition.before == value.text &&
                  transition.after == newValue.text,
            ) =>
          _restoreMatching(
            source: _future,
            destination: _past,
            current: current,
            targetText: newValue.text,
          ),
        null => null,
      };
      if (restored != null) {
        _emphasis = restored.emphasis;
        _links = restored.links;
      } else {
        _past.add(current);
        _future.clear();
        _emphasis = NoteEmphasis.transformEdit(
          oldText: value.text,
          newText: newValue.text,
          ranges: _emphasis,
        );
        _links = NoteTextLinks.transformEdit(
          oldText: value.text,
          newText: newValue.text,
          ranges: _links,
        );
        if (imported != null) {
          _structuredTransitions.add((
            before: current.text,
            after: newValue.text,
          ));
          _emphasis = NoteEmphasis.merge(
            textLength: newValue.text.length,
            ranges: _emphasis,
            additions: [
              for (final range in imported.emphasis)
                NoteEmphasisRange(
                  start: insertionStart + range.start,
                  end: insertionStart + range.end,
                  bold: range.bold,
                  italic: range.italic,
                ),
            ],
          );
          _links = NoteTextLinks.merge(
            textLength: newValue.text.length,
            ranges: _links,
            additions: [
              for (final link in imported.links)
                NoteTextLinkRange(
                  start: insertionStart + link.start,
                  end: insertionStart + link.end,
                  destination: link.destination,
                ),
            ],
          );
        }
      }
    }
    _historyDirection = null;
    super.value = newValue;
  }

  void prepareUndo() => _historyDirection = _TextHistoryDirection.undo;

  void prepareRedo() => _historyDirection = _TextHistoryDirection.redo;

  void updatePresentation({
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
  }) {
    if (_emphasisRangesEqual(_emphasis, emphasis) &&
        _linkRangesEqual(_links, links)) {
      return;
    }
    _emphasis = List.unmodifiable(emphasis);
    _links = List.unmodifiable(links);
    notifyListeners();
  }

  void applyStructuredEdit(NoteListTransformation transformation) {
    final current = _TextPresentationSnapshot(
      text: text,
      emphasis: _emphasis,
      links: _links,
    );
    _past.add(current);
    _future.clear();
    _structuredTransitions.add((
      before: current.text,
      after: transformation.text,
    ));
    _replacingFromModel = true;
    try {
      _emphasis = transformation.emphasis;
      _links = transformation.links;
      super.value = TextEditingValue(
        text: transformation.text,
        selection: transformation.selection,
      );
    } finally {
      _replacingFromModel = false;
    }
  }

  void replaceFromModel({
    required String text,
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
  }) {
    final currentSelection = selection;
    final nextSelection = currentSelection.isValid
        ? TextSelection(
            baseOffset: currentSelection.baseOffset.clamp(0, text.length),
            extentOffset: currentSelection.extentOffset.clamp(0, text.length),
            affinity: currentSelection.affinity,
            isDirectional: currentSelection.isDirectional,
          )
        : TextSelection.collapsed(offset: text.length);
    _replacingFromModel = true;
    try {
      _emphasis = List.unmodifiable(emphasis);
      _links = List.unmodifiable(links);
      super.value = TextEditingValue(text: text, selection: nextSelection);
    } finally {
      _replacingFromModel = false;
    }
  }

  _TextPresentationSnapshot? _restoreMatching({
    required List<_TextPresentationSnapshot> source,
    required List<_TextPresentationSnapshot> destination,
    required _TextPresentationSnapshot current,
    required String targetText,
  }) {
    for (var index = source.length - 1; index >= 0; index--) {
      final snapshot = source[index];
      if (snapshot.text != targetText) {
        continue;
      }
      destination.add(current);
      source.removeRange(index, source.length);
      return snapshot;
    }
    return null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_emphasis.isEmpty && _links.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    final children = <InlineSpan>[];
    final boundaries = <int>{0, text.length};
    for (final range in _emphasis) {
      boundaries
        ..add(range.start)
        ..add(range.end);
    }
    for (final range in _links) {
      boundaries
        ..add(range.start)
        ..add(range.end);
    }
    final ordered = boundaries.toList()..sort();
    for (var index = 0; index < ordered.length - 1; index++) {
      final start = ordered[index];
      final end = ordered[index + 1];
      if (start == end) {
        continue;
      }
      final emphasis = _emphasisRangeAt(_emphasis, start);
      final link = NoteTextLinks.linkAt(_links, start);
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: link == null ? null : const Color(0xFF174F8A),
            fontWeight: emphasis?.bold ?? false ? FontWeight.bold : null,
            fontStyle: emphasis?.italic ?? false ? FontStyle.italic : null,
            decoration: (emphasis?.underline ?? false) || link != null
                ? TextDecoration.underline
                : null,
            decorationThickness: link == null ? null : 1.3,
          ),
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

enum _TextHistoryDirection { undo, redo }

class _TextPresentationSnapshot {
  _TextPresentationSnapshot({
    required this.text,
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
  }) : emphasis = List.unmodifiable(emphasis),
       links = List.unmodifiable(links);

  final String text;
  final List<NoteEmphasisRange> emphasis;
  final List<NoteTextLinkRange> links;
}

class _NotePresentationSnapshot {
  _NotePresentationSnapshot({
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
  }) : emphasis = List.unmodifiable(emphasis),
       links = List.unmodifiable(links);

  final List<NoteEmphasisRange> emphasis;
  final List<NoteTextLinkRange> links;
}

class _PendingLinkActivation {
  const _PendingLinkActivation({
    required this.link,
    required this.selection,
    required this.position,
  });

  final NoteTextLinkRange link;
  final TextSelection selection;
  final Offset position;
}

NoteEmphasisRange? _emphasisRangeAt(
  List<NoteEmphasisRange> ranges,
  int offset,
) {
  for (final range in ranges) {
    if (offset >= range.start && offset < range.end) {
      return range;
    }
  }
  return null;
}

bool _emphasisRangesEqual(
  List<NoteEmphasisRange> left,
  List<NoteEmphasisRange> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _linkRangesEqual(
  List<NoteTextLinkRange> left,
  List<NoteTextLinkRange> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
