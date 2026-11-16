import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board_shape.dart';
import 'shape_definition.dart';
import 'shape_layer.dart';

class ShapeSidePanel extends StatelessWidget {
  const ShapeSidePanel({
    required this.shapes,
    required this.layers,
    required this.activeLayerId,
    required this.soloLayerId,
    required this.selectedShapeId,
    required this.armedType,
    required this.onArm,
    this.isCircleArmed = false,
    this.onArmCircle,
    required this.onSelect,
    required this.onSelectLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacity,
    required this.onToggleSoloLayer,
    required this.onExitSolo,
    required this.onAddLayer,
    required this.onRenameLayer,
    required this.onMoveLayerForward,
    required this.onMoveLayerBackward,
    required this.onDeleteLayer,
    required this.onMoveShapeToLayer,
    required this.onClose,
    required this.onDuplicate,
    required this.onDelete,
    required this.canAddSelectedToGroup,
    required this.canRemoveSelectedFromGroup,
    required this.onAddSelectedToGroup,
    required this.onRemoveSelectedFromGroup,
    required this.onMoveForward,
    required this.onMoveBackward,
    required this.onFillColor,
    required this.onOutlineColor,
    required this.onHeadingColor,
    required this.onFillOpacityStart,
    required this.onFillOpacityChanged,
    required this.onFillOpacityEnd,
    required this.onOutlineWidth,
    required this.onRouteAxis,
    required this.onEditHeading,
    required this.onRemoveHeading,
    required this.onHeadingSize,
    required this.onHeadingAlignment,
    required this.onHeadingPlacement,
    super.key,
  });

  final List<BoardShape> shapes;
  final List<ShapeLayer> layers;
  final String activeLayerId;
  final String? soloLayerId;
  final String? selectedShapeId;
  final BoardShapeType? armedType;
  final ValueChanged<BoardShapeType?> onArm;
  final bool isCircleArmed;
  final VoidCallback? onArmCircle;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSelectLayer;
  final ValueChanged<String> onToggleLayerVisibility;
  final void Function(String layerId, double opacity) onLayerOpacity;
  final ValueChanged<String> onToggleSoloLayer;
  final VoidCallback onExitSolo;
  final VoidCallback onAddLayer;
  final VoidCallback onRenameLayer;
  final VoidCallback onMoveLayerForward;
  final VoidCallback onMoveLayerBackward;
  final VoidCallback onDeleteLayer;
  final ValueChanged<String> onMoveShapeToLayer;
  final VoidCallback onClose;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final bool canAddSelectedToGroup;
  final bool canRemoveSelectedFromGroup;
  final VoidCallback onAddSelectedToGroup;
  final VoidCallback onRemoveSelectedFromGroup;
  final VoidCallback onMoveForward;
  final VoidCallback onMoveBackward;
  final VoidCallback onFillColor;
  final VoidCallback onOutlineColor;
  final VoidCallback onHeadingColor;
  final VoidCallback onFillOpacityStart;
  final ValueChanged<double> onFillOpacityChanged;
  final VoidCallback onFillOpacityEnd;
  final ValueChanged<double> onOutlineWidth;
  final ValueChanged<OrthogonalRouteAxis> onRouteAxis;
  final VoidCallback onEditHeading;
  final VoidCallback onRemoveHeading;
  final ValueChanged<double> onHeadingSize;
  final ValueChanged<ShapeHeadingAlignment> onHeadingAlignment;
  final ValueChanged<ShapeHeadingPlacement> onHeadingPlacement;

  @override
  Widget build(BuildContext context) {
    final selected = selectedShapeId == null
        ? null
        : shapes.cast<BoardShape?>().firstWhere(
            (shape) => shape!.id == selectedShapeId,
            orElse: () => null,
          );
    final selectedIndex = selected == null
        ? -1
        : shapes.indexWhere((shape) => shape.id == selected.id);
    final activeLayerIndex = layers.indexWhere(
      (layer) => layer.id == activeLayerId,
    );
    final activeLayer = layers[activeLayerIndex];
    return Material(
      key: const ValueKey('shape-side-panel'),
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 320,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Shapes'),
              subtitle: Text(
                armedType == null
                    ? 'Select or draw one shape'
                    : 'Drag on the board to draw',
              ),
              trailing: IconButton(
                key: const ValueKey('close-shapes-mode'),
                tooltip: 'Close Shapes mode',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: ValueKey('shape-panel-list-${selectedShapeId ?? 'none'}'),
                padding: const EdgeInsets.all(12),
                children: [
                  ExpansionTile(
                    key: ValueKey('shape-tools-${selectedShapeId ?? 'none'}'),
                    title: const Text('Choose a Shape'),
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    children: [
                      _ShapeCatalogue(
                        armedType: armedType,
                        enabled: activeLayer.isVisible,
                        onArm: onArm,
                        isCircleArmed: isCircleArmed,
                        onArmCircle: onArmCircle,
                      ),
                    ],
                  ),
                  if (selected != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selected shape',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          key: ValueKey(
                            canRemoveSelectedFromGroup
                                ? 'remove-shape-from-group'
                                : 'add-shape-to-group',
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: canRemoveSelectedFromGroup
                              ? onRemoveSelectedFromGroup
                              : canAddSelectedToGroup
                              ? onAddSelectedToGroup
                              : null,
                          icon: Icon(
                            canRemoveSelectedFromGroup
                                ? Icons.folder_off_outlined
                                : Icons.create_new_folder_outlined,
                            size: 18,
                          ),
                          label: Text(
                            canRemoveSelectedFromGroup
                                ? 'Remove from group'
                                : 'Add to group...',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ColorButton(
                            label: 'Outline',
                            value: selected.outlineColorValue,
                            onPressed: onOutlineColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<double>(
                          value: selected.outlineWidth,
                          items: [
                            for (final width
                                in BoardShape.supportedOutlineWidths)
                              DropdownMenuItem(
                                value: width,
                                child: Text('${width.toInt()} px'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) onOutlineWidth(value);
                          },
                        ),
                      ],
                    ),
                    if (selected.type.supportsFill) ...[
                      const SizedBox(height: 10),
                      _ColorButton(
                        label: 'Fill colour',
                        value: selected.fillColorValue,
                        onPressed: onFillColor,
                      ),
                      Row(
                        children: [
                          const Text('Fill'),
                          Expanded(
                            child: Slider(
                              key: const ValueKey('shape-fill-opacity'),
                              value: selected.fillOpacity,
                              onChangeStart: (_) => onFillOpacityStart(),
                              onChanged: onFillOpacityChanged,
                              onChangeEnd: (_) => onFillOpacityEnd(),
                            ),
                          ),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${(selected.fillOpacity * 100).round()}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (selected.isOrthogonal) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Route direction',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<OrthogonalRouteAxis>(
                        key: const ValueKey('orthogonal-route-axis'),
                        segments: const [
                          ButtonSegment(
                            value: OrthogonalRouteAxis.horizontalFirst,
                            label: Text('Across first'),
                          ),
                          ButtonSegment(
                            value: OrthogonalRouteAxis.verticalFirst,
                            label: Text('Down first'),
                          ),
                        ],
                        selected: {selected.routeAxis},
                        onSelectionChanged: (values) =>
                            onRouteAxis(values.first),
                      ),
                    ],
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const ValueKey('edit-shape-heading'),
                            onPressed: onEditHeading,
                            icon: const Icon(Icons.title),
                            label: Text(
                              selected.heading == null
                                  ? 'Add heading'
                                  : 'Edit heading',
                            ),
                          ),
                        ),
                        if (selected.heading != null)
                          IconButton(
                            tooltip: 'Remove heading',
                            onPressed: onRemoveHeading,
                            icon: const Icon(Icons.title_outlined),
                          ),
                      ],
                    ),
                    if (selected.heading case final heading?) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ColorButton(
                              label: 'Text colour',
                              value: heading.colorValue,
                              onPressed: onHeadingColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<double>(
                            value: heading.fontSize,
                            items: [
                              for (final size
                                  in ShapeHeading.supportedFontSizes)
                                DropdownMenuItem(
                                  value: size,
                                  child: Text('${size.toInt()} pt'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) onHeadingSize(value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ShapeHeadingAlignment>(
                        segments: const [
                          ButtonSegment(
                            value: ShapeHeadingAlignment.left,
                            icon: Icon(Icons.format_align_left),
                          ),
                          ButtonSegment(
                            value: ShapeHeadingAlignment.center,
                            icon: Icon(Icons.format_align_center),
                          ),
                          ButtonSegment(
                            value: ShapeHeadingAlignment.right,
                            icon: Icon(Icons.format_align_right),
                          ),
                        ],
                        selected: {heading.alignment},
                        onSelectionChanged: (values) =>
                            onHeadingAlignment(values.first),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ShapeHeadingPlacement>(
                        initialValue: heading.placement,
                        decoration: const InputDecoration(
                          labelText: 'Heading position',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ShapeHeadingPlacement.insideTop,
                            child: Text('Inside top'),
                          ),
                          DropdownMenuItem(
                            value: ShapeHeadingPlacement.above,
                            child: Text('Above shape'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) onHeadingPlacement(value);
                        },
                      ),
                    ],
                    const Divider(height: 28),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: selectedIndex < shapes.length - 1
                              ? onMoveForward
                              : null,
                          icon: const Icon(Icons.flip_to_front, size: 18),
                          label: const Text('Forward'),
                        ),
                        OutlinedButton.icon(
                          onPressed: selectedIndex > 0 ? onMoveBackward : null,
                          icon: const Icon(Icons.flip_to_back, size: 18),
                          label: const Text('Backward'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onDuplicate,
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: const Text('Duplicate'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                    if (layers.length > 1) ...[
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Move to layer',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const ValueKey('move-shape-to-layer'),
                            value: activeLayerId,
                            isExpanded: true,
                            items: [
                              for (final layer in layers.reversed)
                                DropdownMenuItem(
                                  value: layer.id,
                                  enabled:
                                      layer.id == activeLayerId ||
                                      layer.isVisible,
                                  child: Text(
                                    layer.isVisible
                                        ? layer.name
                                        : '${layer.name} (hidden)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null && value != activeLayerId) {
                                onMoveShapeToLayer(value);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                  const Divider(height: 28),
                  if (soloLayerId != null)
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.filter_center_focus),
                        title: const Text('Solo layer view'),
                        trailing: TextButton(
                          key: const ValueKey('exit-shape-layer-solo'),
                          onPressed: onExitSolo,
                          child: const Text('Exit Solo'),
                        ),
                      ),
                    ),
                  ExpansionTile(
                    key: const ValueKey('shape-layers-rollup'),
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Layers',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: const ValueKey('add-shape-layer'),
                          onPressed: soloLayerId == null ? onAddLayer : null,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add layer'),
                        ),
                      ),
                      for (final layer in layers.reversed)
                        ListTile(
                          key: ValueKey('shape-layer-${layer.id}'),
                          dense: true,
                          selected: layer.id == activeLayerId,
                          leading: IconButton(
                            key: ValueKey('shape-layer-visibility-${layer.id}'),
                            tooltip: layer.isVisible
                                ? 'Hide ${layer.name}'
                                : 'Show ${layer.name}',
                            onPressed: soloLayerId == null
                                ? () => onToggleLayerVisibility(layer.id)
                                : null,
                            icon: Icon(
                              layer.isVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          title: Text(
                            layer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${layer.isVisible ? '' : 'Hidden · '}'
                                  '${layer.shapeIds.length} '
                                  '${layer.shapeIds.length == 1 ? 'shape' : 'shapes'}'
                                  ' · ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<double>(
                                key: ValueKey(
                                  'shape-layer-opacity-control-${layer.id}',
                                ),
                                tooltip: 'Change ${layer.name} opacity',
                                enabled: layer.isVisible,
                                padding: EdgeInsets.zero,
                                onSelected: (opacity) =>
                                    onLayerOpacity(layer.id, opacity),
                                itemBuilder: (context) => [
                                  for (final opacity
                                      in ShapeLayer.supportedOpacities)
                                    CheckedPopupMenuItem(
                                      key: ValueKey(
                                        'shape-layer-opacity-option-${layer.id}-'
                                        '${(opacity * 100).round()}',
                                      ),
                                      value: opacity,
                                      checked: layer.opacity == opacity,
                                      child: Text(
                                        '${(opacity * 100).round()}%',
                                      ),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${(layer.opacity * 100).round()}%',
                                    style: TextStyle(
                                      color: layer.isVisible
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      decoration: layer.isVisible
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: TextButton(
                            key: ValueKey('solo-shape-layer-${layer.id}'),
                            onPressed: layer.isVisible
                                ? () => onToggleSoloLayer(layer.id)
                                : null,
                            child: Text(
                              soloLayerId == layer.id ? 'Exit' : 'Solo',
                            ),
                          ),
                          enabled: soloLayerId == null || layer.isVisible,
                          onTap: soloLayerId == null || layer.isVisible
                              ? () => onSelectLayer(layer.id)
                              : null,
                        ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('rename-shape-layer'),
                            onPressed: onRenameLayer,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Rename'),
                          ),
                          IconButton.outlined(
                            key: const ValueKey('shape-layer-forward'),
                            tooltip: 'Move layer forward',
                            onPressed: activeLayerIndex < layers.length - 1
                                ? onMoveLayerForward
                                : null,
                            icon: const Icon(Icons.flip_to_front, size: 18),
                          ),
                          IconButton.outlined(
                            key: const ValueKey('shape-layer-backward'),
                            tooltip: 'Move layer backward',
                            onPressed: activeLayerIndex > 0
                                ? onMoveLayerBackward
                                : null,
                            icon: const Icon(Icons.flip_to_back, size: 18),
                          ),
                          IconButton.outlined(
                            key: const ValueKey('delete-shape-layer'),
                            tooltip: activeLayer.shapeIds.isNotEmpty
                                ? 'Move or delete its shapes first'
                                : layers.length == 1
                                ? 'A Board needs one shape layer'
                                : 'Delete empty shape layer',
                            onPressed:
                                soloLayerId == null &&
                                    layers.length > 1 &&
                                    activeLayer.shapeIds.isEmpty
                                ? onDeleteLayer
                                : null,
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                      if (activeLayer.shapeIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Move or delete this layer’s shapes before deleting it.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 28),
                  if (!activeLayer.isVisible)
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'This layer is hidden. Show it to draw, select, '
                              'or edit its shapes.',
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              key: const ValueKey('show-active-shape-layer'),
                              onPressed: soloLayerId == null
                                  ? () =>
                                        onToggleLayerVisibility(activeLayer.id)
                                  : null,
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Show layer to select shape'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!activeLayer.isVisible) const SizedBox(height: 12),
                  ExpansionTile(
                    key: const ValueKey('shape-order-rollup'),
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Shape order',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    children: [
                      if (shapes.isEmpty)
                        const Text('No shapes yet. Choose a tool, then drag.')
                      else
                        for (final indexed in shapes.reversed.indexed)
                          ListTile(
                            key: ValueKey('shape-row-${indexed.$2.id}'),
                            dense: true,
                            selected: indexed.$2.id == selectedShapeId,
                            leading: Icon(
                              ShapeDefinition.forType(indexed.$2.type).icon,
                            ),
                            title: Text(
                              indexed.$2.heading?.text ?? indexed.$2.type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(indexed.$2.type.label),
                            enabled: activeLayer.isVisible,
                            onTap: activeLayer.isVisible
                                ? () => onSelect(indexed.$2.id)
                                : null,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeCatalogue extends StatelessWidget {
  const _ShapeCatalogue({
    required this.armedType,
    required this.enabled,
    required this.onArm,
    required this.isCircleArmed,
    required this.onArmCircle,
  });

  final BoardShapeType? armedType;
  final bool enabled;
  final ValueChanged<BoardShapeType?> onArm;
  final bool isCircleArmed;
  final VoidCallback? onArmCircle;

  @override
  Widget build(BuildContext context) {
    final categories = ShapeDefinition.definitions
        .map((definition) => definition.category)
        .toSet();
    return Column(
      key: const ValueKey('shape-tool-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CatalogueButton(
          label: 'Select',
          icon: Icons.near_me_outlined,
          selected: armedType == null,
          onPressed: enabled ? () => onArm(null) : null,
        ),
        for (final category in categories) ...[
          const SizedBox(height: 12),
          Text(category, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final definition in ShapeDefinition.definitions)
                if (definition.category == category) ...[
                  _CatalogueButton(
                    label: definition.type.label,
                    icon: definition.icon,
                    selected:
                        armedType == definition.type &&
                        !(definition.type == BoardShapeType.ellipse &&
                            isCircleArmed),
                    onPressed: enabled ? () => onArm(definition.type) : null,
                  ),
                  if (definition.type == BoardShapeType.ellipse)
                    _CatalogueButton(
                      label: 'Circle',
                      icon: Icons.circle_outlined,
                      selected: isCircleArmed,
                      onPressed: enabled ? onArmCircle : null,
                    ),
                ],
            ],
          ),
        ],
      ],
    );
  }
}

class _CatalogueButton extends StatelessWidget {
  const _CatalogueButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton.filledTonal(
      key: ValueKey('shape-tool-${label.toLowerCase().replaceAll(' ', '-')}'),
      isSelected: selected,
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });
  final String label;
  final int value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Color(value),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    label: Text(label),
  );
}

Future<int?> showShapeColorDialog(BuildContext context, int initialValue) {
  return showDialog<int>(
    context: context,
    builder: (context) => _ShapeColorDialog(initialValue: initialValue),
  );
}

class _ShapeColorDialog extends StatefulWidget {
  const _ShapeColorDialog({required this.initialValue});
  final int initialValue;

  @override
  State<_ShapeColorDialog> createState() => _ShapeColorDialogState();
}

class _ShapeColorDialogState extends State<_ShapeColorDialog> {
  static const _swatches = <int>[
    0xFF000000,
    0xFFFFFFFF,
    0xFF455A64,
    0xFFE53935,
    0xFFFF9800,
    0xFFFFEB3B,
    0xFF43A047,
    0xFF00ACC1,
    0xFF1E88E5,
    0xFF3949AB,
    0xFF8E24AA,
    0xFFD81B60,
  ];
  late HSVColor _hsv;
  late final TextEditingController _hexController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(Color(widget.initialValue));
    _hexController = TextEditingController(text: _hexValue);
  }

  String get _hexValue =>
      _hsv.toColor().toARGB32().toRadixString(16).substring(2).toUpperCase();

  void _update(HSVColor value) {
    setState(() {
      _hsv = value;
      _hexController.text = _hexValue;
      _error = null;
    });
  }

  void _applyHex() {
    final value = _hexController.text.trim().replaceFirst('#', '');
    final parsed = int.tryParse(value, radix: 16);
    if (value.length != 6 || parsed == null) {
      setState(() => _error = 'Enter six hexadecimal digits.');
      return;
    }
    _update(HSVColor.fromColor(Color(0xFF000000 | parsed)));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose colour'),
    content: SizedBox(
      width: 360,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _hsv.toColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in _swatches)
                    InkWell(
                      key: ValueKey('shape-colour-swatch-$value'),
                      onTap: () => _update(HSVColor.fromColor(Color(value))),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: Color(value) == _hsv.toColor() ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 176,
                height: 176,
                child: GestureDetector(
                  onPanDown: (details) => _pickWheel(details.localPosition),
                  onPanUpdate: (details) => _pickWheel(details.localPosition),
                  child: CustomPaint(painter: _HueWheelPainter(hue: _hsv.hue)),
                ),
              ),
              _HsvSlider(
                label: 'Hue',
                value: _hsv.hue,
                max: 360,
                onChanged: (value) => _update(_hsv.withHue(value)),
              ),
              _HsvSlider(
                label: 'Saturation',
                value: _hsv.saturation,
                max: 1,
                onChanged: (value) => _update(_hsv.withSaturation(value)),
              ),
              _HsvSlider(
                label: 'Brightness',
                value: _hsv.value,
                max: 1,
                onChanged: (value) => _update(_hsv.withValue(value)),
              ),
              TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  prefixText: '#',
                  labelText: 'Hex colour',
                  errorText: _error,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _applyHex(),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          _applyHex();
          if (_error == null) Navigator.pop(context, _hsv.toColor().toARGB32());
        },
        child: const Text('Use colour'),
      ),
    ],
  );

  void _pickWheel(Offset point) {
    final offset = point - const Offset(88, 88);
    if (offset.distance < 48 || offset.distance > 88) return;
    final angle = math.atan2(offset.dy, offset.dx) * 180 / math.pi;
    _update(_hsv.withHue((angle + 360) % 360));
  }
}

class _HueWheelPainter extends CustomPainter {
  const _HueWheelPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;
    for (var degree = 0; degree < 360; degree += 2) {
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1, degree.toDouble(), 1, 1).toColor()
        ..strokeWidth = 24
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        degree * math.pi / 180,
        3 * math.pi / 180,
        false,
        paint,
      );
    }
    final angle = hue * math.pi / 180;
    final marker = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(marker, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      8,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HsvSlider extends StatelessWidget {
  const _HsvSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 76, child: Text(label)),
      Expanded(
        child: Slider(value: value, max: max, onChanged: onChanged),
      ),
    ],
  );
}
