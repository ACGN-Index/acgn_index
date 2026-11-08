import 'package:acgn_index/features/sources/rule_editor/editor_controls.dart';
import 'package:acgn_index/features/sources/rule_editor/field_rule_fields_editor.dart';
import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// 表单化的规则编辑视图，与 JSON 模式共享同一份 [RuleDraft]。
class VisualRuleEditor extends StatefulWidget {
  const VisualRuleEditor({required this.draft, required this.readOnly, super.key});

  final RuleDraft draft;
  final bool readOnly;

  @override
  State<VisualRuleEditor> createState() => _VisualRuleEditorState();
}

class _VisualRuleEditorState extends State<VisualRuleEditor> {
  static const String _schemaVersionKey = 'schemaVersion';

  int _section = 0;

  RuleDraft get _draft => widget.draft;

  Map<String, Object?> get _json => _draft.json;

  Map<String, Object?> get _meta => asJsonMapOrNull(_json['meta']) ?? const <String, Object?>{};

  Map<String, Object?> get _request =>
      asJsonMapOrNull(_json['request']) ?? const <String, Object?>{};

  Map<String, Object?>? _capability(String key) {
    final capabilities = asJsonMapOrNull(_json['capabilities']);
    return asJsonMapOrNull(capabilities?[key]);
  }

  void _updateMeta(void Function(Map<String, Object?> meta) action) {
    _draft.mutate((json) => action(ensureJsonMap(json, 'meta')));
  }

  void _updateRequest(void Function(Map<String, Object?> request) action) {
    _draft.mutate((json) => action(ensureJsonMap(json, 'request')));
  }

  void _updateCapability(
    String key,
    void Function(Map<String, Object?> capability) action,
  ) {
    _draft.mutate((json) {
      final capabilities = ensureJsonMap(json, 'capabilities');
      action(ensureJsonMap(capabilities, key));
    });
  }

  void _setCapabilityEnabled(String key, bool enabled) {
    _draft.mutate((json) {
      final capabilities = ensureJsonMap(json, 'capabilities');
      if (enabled) {
        capabilities[key] = defaultCapabilityJson(
          key,
          contentMode: key == 'content' ? defaultContentMode(readString(_meta, 'type')) : null,
        );
      } else {
        capabilities.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        _sectionSelector(l10n),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: IgnorePointer(
                  ignoring: widget.readOnly,
                  child: AnimatedBuilder(
                    animation: _draft,
                    builder: (context, _) => _buildSection(l10n),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionSelector(AppLocalizations l10n) {
    final sections = <(String, IconData)>[
      (l10n.ruleSectionBasic, Icons.badge_outlined),
      (l10n.ruleSectionRequest, Icons.http),
      (l10n.ruleSectionSearch, Icons.search),
      (l10n.ruleSectionDetail, Icons.info_outline),
      (l10n.ruleSectionToc, Icons.list_alt_outlined),
      (l10n.ruleSectionContent, Icons.article_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (var index = 0; index < sections.length; index++)
            ChoiceChip(
              label: Text(sections[index].$1),
              avatar: Icon(sections[index].$2, size: 18),
              selected: _section == index,
              showCheckmark: false,
              onSelected: (_) => setState(() => _section = index),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(AppLocalizations l10n) => switch (_section) {
    0 => _basicSection(l10n),
    1 => _requestSection(l10n),
    2 => _searchSection(l10n),
    3 => _detailSection(l10n),
    4 => _tocSection(l10n),
    _ => _contentSection(l10n),
  };

  Widget _basicSection(AppLocalizations l10n) {
    final meta = _meta;
    return EditorSectionCard(
      title: l10n.ruleSectionBasic,
      description: l10n.ruleSectionBasicDesc,
      icon: Icons.badge_outlined,
      children: <Widget>[
        EditorNumberField(
          label: _schemaVersionKey,
          value: readInt(_json, _schemaVersionKey, 1),
          onChanged: (value) => _draft.mutate((json) => json[_schemaVersionKey] = value),
        ),
        EditorTextField(
          key: const ValueKey<String>('visual.meta.id'),
          label: l10n.ruleFieldId,
          hint: l10n.ruleFieldIdHint,
          value: readString(meta, 'id'),
          onChanged: (text) =>
              _updateMeta((meta) => writeString(meta, 'id', text.trim(), keepEmpty: true)),
        ),
        EditorTextField(
          key: const ValueKey<String>('visual.meta.name'),
          label: l10n.ruleFieldName,
          value: readString(meta, 'name'),
          onChanged: (text) =>
              _updateMeta((meta) => writeString(meta, 'name', text, keepEmpty: true)),
        ),
        EditorChoiceField<String>(
          label: l10n.ruleFieldType,
          value: readString(meta, 'type'),
          choices: <EditorChoice<String>>[
            EditorChoice(value: 'anime', label: l10n.sourcesTypeAnime),
            EditorChoice(value: 'comic', label: l10n.sourcesTypeComic),
            EditorChoice(value: 'novel', label: l10n.sourcesTypeNovel),
          ],
          onChanged: (value) => _updateMeta((meta) => meta['type'] = value),
        ),
        EditorTextField(
          key: const ValueKey<String>('visual.meta.baseUrl'),
          label: l10n.ruleFieldBaseUrl,
          value: readString(meta, 'baseUrl'),
          onChanged: (text) =>
              _updateMeta((meta) => writeString(meta, 'baseUrl', text.trim(), keepEmpty: true)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: EditorTextField(
                label: l10n.ruleFieldVersion,
                value: readString(meta, 'version'),
                onChanged: (text) => _updateMeta(
                  (meta) => writeString(meta, 'version', text.trim(), keepEmpty: true),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditorTextField(
                label: l10n.ruleFieldAuthor,
                value: readString(meta, 'author'),
                onChanged: (text) => _updateMeta((meta) => writeString(meta, 'author', text)),
              ),
            ),
          ],
        ),
        EditorTextField(
          label: l10n.ruleFieldLang,
          value: readString(meta, 'lang'),
          onChanged: (text) => _updateMeta((meta) => writeString(meta, 'lang', text.trim())),
        ),
        EditorSwitchField(
          label: l10n.ruleFieldAdult,
          helper: l10n.ruleFieldAdultHelp,
          value: readBool(meta, 'adult'),
          onChanged: (value) => _updateMeta((meta) => writeBool(meta, 'adult', value)),
        ),
        EditorTextField(
          label: l10n.ruleFieldDescription,
          value: readString(meta, 'description'),
          maxLines: 2,
          onChanged: (text) => _updateMeta((meta) => writeString(meta, 'description', text)),
        ),
        EditorTextField(
          label: l10n.ruleFieldNotice,
          value: readString(meta, 'notice'),
          maxLines: 2,
          onChanged: (text) => _updateMeta((meta) => writeString(meta, 'notice', text)),
        ),
        EditorStringListField(
          label: l10n.ruleFieldAllowedHosts,
          helper: l10n.ruleFieldAllowedHostsHelp,
          addLabel: l10n.ruleAddHost,
          value: readStringList(meta, 'allowedHosts'),
          onChanged: (values) =>
              _updateMeta((meta) => writeStringList(meta, 'allowedHosts', values)),
        ),
      ],
    );
  }

  Widget _requestSection(AppLocalizations l10n) {
    final request = _request;
    return EditorSectionCard(
      title: l10n.ruleSectionRequest,
      description: l10n.ruleSectionRequestDesc,
      icon: Icons.http,
      children: <Widget>[
        EditorStringMapField(
          label: l10n.ruleFieldHeaders,
          helper: l10n.ruleFieldHeadersHelp,
          addLabel: l10n.ruleAddHeader,
          keyLabel: l10n.ruleHeaderName,
          valueLabel: l10n.ruleHeaderValue,
          value: readStringMap(request, 'headers'),
          onChanged: (values) => _updateRequest((request) {
            writeStringMap(request, 'headers', values);
          }),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: EditorNumberField(
                label: l10n.ruleFieldTimeout,
                value: readInt(request, 'timeoutMs', 15000),
                onChanged: (value) => _updateRequest(
                  (request) => writeInt(request, 'timeoutMs', value, defaultValue: 15000),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditorChoiceField<int>(
                label: l10n.ruleFieldRetry,
                value: readInt(request, 'retry', 0),
                choices: const <EditorChoice<int>>[
                  EditorChoice(value: 0, label: '0'),
                  EditorChoice(value: 1, label: '1'),
                  EditorChoice(value: 2, label: '2'),
                ],
                onChanged: (value) => _updateRequest(
                  (request) => writeInt(request, 'retry', value, defaultValue: 0),
                ),
              ),
            ),
          ],
        ),
        EditorTextField(
          label: l10n.ruleFieldEncoding,
          value: readString(request, 'encoding').isEmpty
              ? 'utf-8'
              : readString(request, 'encoding'),
          onChanged: (text) => _updateRequest((request) {
            final encoding = text.trim();
            if (encoding.isEmpty || encoding == 'utf-8') {
              request.remove('encoding');
            } else {
              request['encoding'] = encoding;
            }
          }),
        ),
      ],
    );
  }

  Widget _searchSection(AppLocalizations l10n) {
    return _capabilityCard(
      l10n: l10n,
      key: 'search',
      title: l10n.ruleSectionSearch,
      description: l10n.ruleSectionSearchDesc,
      icon: Icons.search,
      capability: _capability('search'),
      extra: _searchExtra,
    );
  }

  Widget _detailSection(AppLocalizations l10n) {
    return _capabilityCard(
      l10n: l10n,
      key: 'detail',
      title: l10n.ruleSectionDetail,
      description: l10n.ruleSectionDetailDesc,
      icon: Icons.info_outline,
      capability: _capability('detail'),
      extra: (l10n, capability) => const <Widget>[],
    );
  }

  Widget _tocSection(AppLocalizations l10n) {
    return _capabilityCard(
      l10n: l10n,
      key: 'toc',
      title: l10n.ruleSectionToc,
      description: l10n.ruleSectionTocDesc,
      icon: Icons.list_alt_outlined,
      capability: _capability('toc'),
      extra: _tocExtra,
    );
  }

  Widget _contentSection(AppLocalizations l10n) {
    return _capabilityCard(
      l10n: l10n,
      key: 'content',
      title: l10n.ruleSectionContent,
      description: l10n.ruleSectionContentDesc,
      icon: Icons.article_outlined,
      capability: _capability('content'),
      extra: _contentExtra,
    );
  }

  Widget _capabilityCard({
    required AppLocalizations l10n,
    required String key,
    required String title,
    required String description,
    required IconData icon,
    required Map<String, Object?>? capability,
    required List<Widget> Function(AppLocalizations l10n, Map<String, Object?> capability) extra,
  }) {
    final enabled = capability != null;
    return EditorSectionCard(
      title: title,
      description: description,
      icon: icon,
      children: <Widget>[
        EditorSwitchField(
          key: ValueKey<String>('visual.$key.enabled'),
          label: l10n.ruleCapabilityEnabled,
          helper: enabled ? null : l10n.ruleCapabilityDisabledHint,
          value: enabled,
          onChanged: (value) => _setCapabilityEnabled(key, value),
        ),
        if (capability != null) ..._capabilityCommonFields(l10n, key, capability),
        if (capability != null) ...extra(l10n, capability),
      ],
    );
  }

  List<Widget> _capabilityCommonFields(
    AppLocalizations l10n,
    String key,
    Map<String, Object?> capability,
  ) {
    final method = readString(capability, 'method').isEmpty
        ? 'GET'
        : readString(capability, 'method');
    return <Widget>[
      EditorTextField(
        key: ValueKey<String>('visual.$key.url'),
        label: l10n.ruleFieldUrl,
        value: readString(capability, 'url'),
        hint: switch (key) {
          'search' => l10n.ruleFieldUrlHint,
          'detail' => '/detail/{{id}}',
          'toc' => '/toc/{{id}}',
          _ => '/chapter/{{chapter.id}}',
        },
        onChanged: (text) => _updateCapability(key, (capability) {
          writeString(capability, 'url', text.trim());
        }),
      ),
      EditorChoiceField<String>(
        label: l10n.ruleFieldMethod,
        value: method,
        choices: const <EditorChoice<String>>[
          EditorChoice(value: 'GET', label: 'GET'),
          EditorChoice(value: 'POST', label: 'POST'),
        ],
        onChanged: (value) => _updateCapability(key, (capability) {
          if (value == 'GET') {
            capability.remove('method');
          } else {
            capability['method'] = value;
          }
        }),
      ),
      EditorTextField(
        label: l10n.ruleFieldBody,
        value: readString(capability, 'body'),
        hint: l10n.ruleFieldBodyHint,
        maxLines: 3,
        onChanged: (text) => _updateCapability(key, (capability) {
          writeString(capability, 'body', text);
        }),
      ),
      EditorStringMapField(
        label: l10n.ruleFieldHeaders,
        addLabel: l10n.ruleAddHeader,
        keyLabel: l10n.ruleHeaderName,
        valueLabel: l10n.ruleHeaderValue,
        value: readStringMap(capability, 'headers'),
        onChanged: (values) => _updateCapability(key, (capability) {
          writeStringMap(capability, 'headers', values);
        }),
      ),
      EditorFieldRuleTile(
        label: l10n.ruleFieldList,
        helper: l10n.ruleFieldListHelp,
        fieldKey: ValueKey<String>('$key.list'),
        value: asJsonMapOrNull(capability['list']),
        onChanged: (updated) => _updateCapability(key, (capability) {
          if (updated == null) {
            capability.remove('list');
          } else {
            capability['list'] = updated;
          }
        }),
      ),
      EditorFieldRuleMapField(
        label: l10n.ruleFieldFields,
        keyPrefix: key,
        value: asJsonMapOrNull(capability['fields']) ?? const <String, Object?>{},
        suggestions: kCapabilityFieldSuggestions[key] ?? const <String>[],
        onChanged: (fields) => _updateCapability(key, (capability) {
          if (fields.isEmpty) {
            capability.remove('fields');
          } else {
            capability['fields'] = fields;
          }
        }),
      ),
    ];
  }

  List<Widget> _searchExtra(
    AppLocalizations l10n,
    Map<String, Object?> capability,
  ) {
    final mode = readString(capability, 'mode') == 'index' ? 'index' : 'query';
    final index = asJsonMapOrNull(capability['index']);
    final pagination = asJsonMapOrNull(capability['pagination']);
    return <Widget>[
      EditorChoiceField<String>(
        label: l10n.ruleSearchMode,
        value: mode,
        helper: mode == 'index' ? l10n.ruleSearchModeHelpIndex : l10n.ruleSearchModeHelpQuery,
        choices: <EditorChoice<String>>[
          EditorChoice(value: 'query', label: l10n.ruleSearchModeQuery),
          EditorChoice(value: 'index', label: l10n.ruleSearchModeIndex),
        ],
        onChanged: (value) => _updateCapability('search', (capability) {
          if (value == 'query') {
            capability
              ..remove('mode')
              ..remove('index')
              ..remove('filter');
          } else {
            capability['mode'] = 'index';
            capability['index'] = <String, Object?>{
              'url': '',
              'list': <String, Object?>{'selector': ''},
            };
            capability['filter'] = <String, Object?>{'js': 'value => true'};
          }
        }),
      ),
      if (mode == 'index') _indexEditor(l10n, capability, index),
      EditorNumberField(
        label: l10n.ruleSearchPageSize,
        value: readInt(capability, 'pageSize', 20),
        onChanged: (value) => _updateCapability('search', (capability) {
          writeInt(capability, 'pageSize', value, defaultValue: 20);
        }),
      ),
      EditorSwitchField(
        label: l10n.ruleSearchPagination,
        helper: l10n.ruleSearchPaginationHelp,
        value: pagination != null,
        onChanged: (enabled) => _updateCapability('search', (capability) {
          if (enabled) {
            capability['pagination'] = <String, Object?>{'pageSize': 20};
          } else {
            capability.remove('pagination');
          }
        }),
      ),
      if (pagination != null) ...<Widget>[
        EditorFieldRuleTile(
          label: l10n.ruleSearchTotalItems,
          fieldKey: const ValueKey<String>('search.pagination.totalItems'),
          value: asJsonMapOrNull(pagination['totalItems']),
          onChanged: (updated) => _updateCapability('search', (capability) {
            final pagination = ensureJsonMap(capability, 'pagination');
            if (updated == null) {
              pagination.remove('totalItems');
            } else {
              pagination['totalItems'] = updated;
            }
          }),
        ),
        EditorNumberField(
          label: l10n.ruleSearchPaginationPageSize,
          value: readInt(pagination, 'pageSize', 20),
          onChanged: (value) => _updateCapability('search', (capability) {
            final pagination = ensureJsonMap(capability, 'pagination');
            writeInt(pagination, 'pageSize', value, defaultValue: 20);
          }),
        ),
      ],
    ];
  }

  Widget _indexEditor(
    AppLocalizations l10n,
    Map<String, Object?> capability,
    Map<String, Object?>? index,
  ) {
    final rule = index ?? const <String, Object?>{};
    final method = readString(rule, 'method').isEmpty ? 'GET' : readString(rule, 'method');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        Text(
          l10n.ruleSearchIndexRequest,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        EditorTextField(
          label: l10n.ruleFieldUrl,
          value: readString(rule, 'url'),
          onChanged: (text) => _updateCapability('search', (capability) {
            writeString(ensureJsonMap(capability, 'index'), 'url', text.trim());
          }),
        ),
        EditorChoiceField<String>(
          label: l10n.ruleFieldMethod,
          value: method,
          choices: const <EditorChoice<String>>[
            EditorChoice(value: 'GET', label: 'GET'),
            EditorChoice(value: 'POST', label: 'POST'),
          ],
          onChanged: (value) => _updateCapability('search', (capability) {
            final index = ensureJsonMap(capability, 'index');
            if (value == 'GET') {
              index.remove('method');
            } else {
              index['method'] = value;
            }
          }),
        ),
        EditorTextField(
          label: l10n.ruleFieldBody,
          value: readString(rule, 'body'),
          hint: l10n.ruleFieldBodyHint,
          maxLines: 3,
          onChanged: (text) => _updateCapability('search', (capability) {
            writeString(ensureJsonMap(capability, 'index'), 'body', text);
          }),
        ),
        EditorNumberField(
          label: l10n.ruleSearchIndexTtl,
          value: readInt(rule, 'ttlSeconds', 3600),
          onChanged: (value) => _updateCapability('search', (capability) {
            writeInt(ensureJsonMap(capability, 'index'), 'ttlSeconds', value, defaultValue: 3600);
          }),
        ),
        EditorFieldRuleTile(
          label: l10n.ruleFieldList,
          helper: l10n.ruleFieldListHelp,
          fieldKey: const ValueKey<String>('search.index.list'),
          value: asJsonMapOrNull(rule['list']),
          onChanged: (updated) => _updateCapability('search', (capability) {
            final index = ensureJsonMap(capability, 'index');
            if (updated == null) {
              index.remove('list');
            } else {
              index['list'] = updated;
            }
          }),
        ),
        EditorFieldRuleTile(
          label: l10n.ruleSearchFilter,
          helper: l10n.ruleSearchFilterHelp,
          fieldKey: const ValueKey<String>('search.filter'),
          value: asJsonMapOrNull(capability['filter']),
          onChanged: (updated) => _updateCapability('search', (capability) {
            if (updated == null) {
              capability.remove('filter');
            } else {
              capability['filter'] = updated;
            }
          }),
        ),
      ],
    );
  }

  List<Widget> _tocExtra(
    AppLocalizations l10n,
    Map<String, Object?> capability,
  ) {
    final group = asJsonMapOrNull(capability['group']);
    return <Widget>[
      EditorTextField(
        label: l10n.ruleTocFanOut,
        hint: l10n.ruleTocFanOutHint,
        helper: l10n.ruleTocFanOutHelp,
        value: readString(capability, 'fanOutFrom'),
        onChanged: (text) => _updateCapability('toc', (capability) {
          writeString(capability, 'fanOutFrom', text.trim());
        }),
      ),
      EditorSwitchField(
        label: l10n.ruleTocGroup,
        helper: l10n.ruleTocGroupHelp,
        value: group != null,
        onChanged: (enabled) => _updateCapability('toc', (capability) {
          if (enabled) {
            capability['group'] = <String, Object?>{'id': 'vid', 'title': 'title'};
          } else {
            capability.remove('group');
          }
        }),
      ),
      if (group != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: EditorTextField(
                label: l10n.ruleTocGroupId,
                value: readString(group, 'id'),
                onChanged: (text) => _updateCapability('toc', (capability) {
                  writeString(
                    ensureJsonMap(capability, 'group'),
                    'id',
                    text.trim(),
                    keepEmpty: true,
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: EditorTextField(
                label: l10n.ruleTocGroupTitle,
                value: readString(group, 'title'),
                onChanged: (text) => _updateCapability('toc', (capability) {
                  writeString(
                    ensureJsonMap(capability, 'group'),
                    'title',
                    text.trim(),
                    keepEmpty: true,
                  );
                }),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _contentExtra(
    AppLocalizations l10n,
    Map<String, Object?> capability,
  ) {
    final mode = readString(capability, 'mode').isEmpty
        ? (defaultContentMode(readString(_meta, 'type')) ?? 'video')
        : readString(capability, 'mode');
    final resolve = asJsonMapOrNull(capability['resolve']);
    final method = resolve == null || readString(resolve, 'method').isEmpty
        ? 'GET'
        : readString(resolve, 'method');
    return <Widget>[
      EditorChoiceField<String>(
        label: l10n.ruleContentMode,
        value: mode,
        choices: <EditorChoice<String>>[
          EditorChoice(value: 'video', label: l10n.ruleContentVideo),
          EditorChoice(value: 'images', label: l10n.ruleContentImages),
          EditorChoice(value: 'text', label: l10n.ruleContentText),
          EditorChoice(value: 'file', label: l10n.ruleContentFile),
        ],
        onChanged: (value) => _updateCapability('content', (capability) {
          capability['mode'] = value;
        }),
      ),
      EditorSwitchField(
        label: l10n.ruleContentResolve,
        helper: l10n.ruleContentResolveHelp,
        value: resolve != null,
        onChanged: (enabled) => _updateCapability('content', (capability) {
          if (enabled) {
            capability['resolve'] = <String, Object?>{'url': ''};
          } else {
            capability.remove('resolve');
          }
        }),
      ),
      if (resolve != null) ...<Widget>[
        EditorTextField(
          label: l10n.ruleFieldUrl,
          value: readString(resolve, 'url'),
          onChanged: (text) => _updateCapability('content', (capability) {
            writeString(ensureJsonMap(capability, 'resolve'), 'url', text.trim());
          }),
        ),
        EditorChoiceField<String>(
          label: l10n.ruleFieldMethod,
          value: method,
          choices: const <EditorChoice<String>>[
            EditorChoice(value: 'GET', label: 'GET'),
            EditorChoice(value: 'POST', label: 'POST'),
          ],
          onChanged: (value) => _updateCapability('content', (capability) {
            final resolve = ensureJsonMap(capability, 'resolve');
            if (value == 'GET') {
              resolve.remove('method');
            } else {
              resolve['method'] = value;
            }
          }),
        ),
        EditorTextField(
          label: l10n.ruleFieldBody,
          value: readString(resolve, 'body'),
          hint: l10n.ruleFieldBodyHint,
          maxLines: 3,
          onChanged: (text) => _updateCapability('content', (capability) {
            writeString(ensureJsonMap(capability, 'resolve'), 'body', text);
          }),
        ),
        EditorFieldRuleMapField(
          label: l10n.ruleFieldFields,
          keyPrefix: 'content.resolve',
          value: asJsonMapOrNull(resolve['fields']) ?? const <String, Object?>{},
          onChanged: (fields) => _updateCapability('content', (capability) {
            final resolve = ensureJsonMap(capability, 'resolve');
            if (fields.isEmpty) {
              resolve.remove('fields');
            } else {
              resolve['fields'] = fields;
            }
          }),
        ),
      ],
    ];
  }
}
