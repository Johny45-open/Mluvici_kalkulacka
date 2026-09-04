part of 'main.dart';

extension on _CalculatorScreenState {
  void _showGuidedStatsCreationDialog() {
    final l10n = _l10n;
    final defaultName = l10n.statsSetDefaultName(_statsSets.length + 1);
    final nameController = TextEditingController(text: defaultName);
    int fieldCount = 1;
    final countController = TextEditingController(text: '1');
    List<TextEditingController> fieldNameControllers = [
      TextEditingController(text: 'Hodnota'),
    ];
    List<String> fieldUnitValues = ['--'];
    int currentFieldIndex = 0;
    int step = 0; // 0=name, 1=count, 2=fields, 3=preview

    const quickNames = [
      'Hodnota',
      'Váha',
      'Výška',
      'Čas',
      'Teplota',
      'Hmotnost',
      'Cena',
      'Množství',
      'Délka',
      'Šířka',
    ];

    String speakNameQuestion() => _s(
          'Jak se bude jmenovat nová sada? Předvyplněno $defaultName. Můžete ponechat nebo přepsat. Odpověď můžete napsat bez háčků a čárek.',
          'What will be the name of the new set? Pre-filled $defaultName. You can keep it or overwrite it. You may type without diacritics.',
        );
    String speakCountQuestion() => _s(
          'Kolik polí bude mít sada? Zadejte číslo 1 až 10. Můžete napsat číslicí nebo slovem, například 3 nebo tri, bez diakritiky.',
          'How many fields will the set have? Enter a number 1 to 10. You can type a digit or a word, e.g. 3 or three, without diacritics.',
        );
    String speakFieldQuestion(int idx, int total) => _s(
          'Jak se jmenuje pole ${idx + 1} z $total? Napište název bez háčků a čárek, nebo vyberte z rychlé nabídky.',
          'What is the name of field ${idx + 1} of $total? Type the name without diacritics, or pick from quick choices.',
        );
    String speakUnitQuestion(String fieldName) => _s(
          'Jaké jednotky pro pole $fieldName? Vyberte jednotku nebo zvolte Bez jednotky. Odpověď bez diakritiky stačí.',
          'What units for field $fieldName? Pick a unit or choose No unit. Answer without diacritics is enough.',
        );

    void speakStep(int s) {
      String text;
      switch (s) {
        case 0:
          text = speakNameQuestion();
          break;
        case 1:
          text = speakCountQuestion();
          break;
        case 2:
          text =
              '${speakFieldQuestion(currentFieldIndex, fieldCount)} ${speakUnitQuestion(fieldNameControllers[currentFieldIndex].text.isEmpty ? _s('Pole ${currentFieldIndex + 1}', 'Field ${currentFieldIndex + 1}') : fieldNameControllers[currentFieldIndex].text)}';
          break;
        case 3:
          final names = fieldNameControllers.map((c) => c.text.trim().isEmpty ? 'Hodnota' : _restoreDiacritics(c.text.trim())).toList();
          final units = List<String?>.generate(names.length, (i) => fieldUnitValues[i] == '--' ? null : fieldUnitValues[i]);
          final fieldsDesc = List.generate(names.length, (i) {
            final u = units[i];
            return u == null ? '${names[i]} bez jednotky' : '${names[i]} ${_getUnitSpeech(u)}';
          }).join(', ');
          final rawName = nameController.text.trim().isEmpty ? defaultName : nameController.text.trim();
          final setNameSpoken = _restoreDiacritics(rawName);
          text = _s(
            'Náhled. Sada $setNameSpoken se ${names.length} poli: $fieldsDesc. Zkontrolujte a potvrďte uložení.',
            'Preview. Set $setNameSpoken with ${names.length} fields: $fieldsDesc. Check and confirm to save.',
          );
          break;
        default:
          text = '';
      }
      if (text.isNotEmpty) speak(text, force: true);
    }

    showAppDialog<void>(
      context: context,
      routeSettings: RouteSettings(name: _s('Průvodce vytvořením sady', 'Set creation wizard')),
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Zajisti správný počet kontrolerů podle fieldCount
            void ensureFieldControllers() {
              while (fieldNameControllers.length < fieldCount) {
                fieldNameControllers.add(TextEditingController(text: _s('Pole ${fieldNameControllers.length + 1}', 'Field ${fieldNameControllers.length + 1}')));
                fieldUnitValues.add('--');
              }
              while (fieldNameControllers.length > fieldCount) {
                fieldNameControllers.removeLast().dispose();
                fieldUnitValues.removeLast();
              }
              if (currentFieldIndex >= fieldCount) currentFieldIndex = fieldCount - 1;
              if (currentFieldIndex < 0) currentFieldIndex = 0;
            }

            // První vyslovení po otevření
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Jen jednou při prvním buildu step 0
            });

            Widget buildNameStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _s('Krok 1 ze 4 — Název sady', 'Step 1 of 4 — Set name'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: _s('Jak se bude jmenovat nová sada', 'What will be the name of the new set'),
                    child: TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _l10n.statsSetNameLabel,
                        hintText: _s('Můžete psát bez háčků a čárek', 'You may type without diacritics'),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        setDialogState(() => step = 1);
                        Future.delayed(const Duration(milliseconds: 300), () => speakStep(1));
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _s('Tip: můžete napsat bez diakritiky, například Skolni test, uloží se jako Školní test.',
                        'Tip: you may type without diacritics, e.g. Skolni test will be saved as Školní test.'),
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              );
            }

            Widget buildCountStep() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _s('Krok 2 ze 4 — Počet polí', 'Step 2 of 4 — Number of fields'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_s('Kolik polí bude mít sada? 1 až 10', 'How many fields will the set have? 1 to 10')),
                  const SizedBox(height: 8),
                  Semantics(
                    label: _s('Počet polí 1 až 10', 'Number of fields 1 to 10'),
                    child: TextField(
                      controller: countController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: _s('Počet polí', 'Number of fields'),
                        hintText: _s('Např. 3 nebo tri', 'E.g. 3 or three'),
                      ),
                      onChanged: (v) {
                        final parsed = _parseNumberAnswer(v);
                        if (parsed != null && parsed >= 1 && parsed <= 10) {
                          setDialogState(() {
                            fieldCount = parsed;
                            ensureFieldControllers();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(10, (i) {
                      final n = i + 1;
                      final selected = fieldCount == n;
                      return ChoiceChip(
                        label: Text('$n'),
                        selected: selected,
                        onSelected: (_) {
                          setDialogState(() {
                            fieldCount = n;
                            countController.text = '$n';
                            ensureFieldControllers();
                          });
                          speak(_s('Zvoleno $n polí', 'Selected $n fields'));
                        },
                      );
                    }),
                  ),
                ],
              );
            }

            Widget buildFieldsStep() {
              ensureFieldControllers();
              final idx = currentFieldIndex;
              final controller = fieldNameControllers[idx];
              final unitVal = fieldUnitValues[idx];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _s('Krok 3 ze 4 — Pole ${idx + 1} z $fieldCount', 'Step 3 of 4 — Field ${idx + 1} of $fieldCount'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: _s('Název pole ${idx + 1}', 'Field ${idx + 1} name'),
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: '${_s('Pole', 'Field')} ${idx + 1}',
                        hintText: _s('Bez háčků a čárek', 'Without diacritics'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: _s('Rychlá volba názvu', 'Quick name picks'),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: quickNames.map((q) {
                        final isSelected = _normalizeAnswer(controller.text) == _normalizeAnswer(q);
                        return ChoiceChip(
                          label: Text(q),
                          selected: isSelected,
                          onSelected: (_) {
                            setDialogState(() => controller.text = q);
                            speak(_s('Zvoleno $q', 'Selected $q'), force: true);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: _s('Jednotka pro pole ${idx + 1}', 'Unit for field ${idx + 1}'),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('unit_${idx}_$fieldCount'),
                      initialValue: unitVal,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _s('Jednotka', 'Unit'),
                      ),
                      items: _statsFieldUnitOptions.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(
                            _getUnitOptionLabel(u),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => fieldUnitValues[idx] = val);
                          final label = _getUnitOptionLabel(val);
                          speak(_s('Zvoleno $label', 'Selected $label'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (idx > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: Text(_s('Předchozí', 'Previous')),
                            onPressed: () {
                              setDialogState(() => currentFieldIndex--);
                              Future.delayed(const Duration(milliseconds: 250), () => speakStep(2));
                            },
                          ),
                        ),
                      if (idx > 0) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(idx == fieldCount - 1 ? Icons.check : Icons.arrow_forward, size: 16),
                          label: Text(idx == fieldCount - 1 ? _s('Hotovo', 'Done') : _s('Další pole', 'Next field')),
                          onPressed: () {
                            if (idx < fieldCount - 1) {
                              setDialogState(() => currentFieldIndex++);
                              Future.delayed(const Duration(milliseconds: 250), () => speakStep(2));
                            } else {
                              setDialogState(() => step = 3);
                              Future.delayed(const Duration(milliseconds: 300), () => speakStep(3));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            Widget buildPreviewStep() {
              final rawName = nameController.text.trim();
              final displayName = rawName.isEmpty ? defaultName : _restoreDiacritics(rawName);
              final names = fieldNameControllers.map((c) {
                final t = c.text.trim();
                return t.isEmpty ? 'Hodnota' : _restoreDiacritics(t);
              }).toList();
              final fieldsDesc = List.generate(names.length, (i) {
                final u = fieldUnitValues[i];
                final unitLabel = u == '--' ? _s('bez jednotky', 'no unit') : _getUnitSpeech(u);
                return '${i + 1}. ${names[i]} ($unitLabel)';
              }).join('\n');

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _s('Krok 4 ze 4 — Náhled', 'Step 4 of 4 — Preview'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            label: _s('Název sady $displayName', 'Set name $displayName'),
                            child: ExcludeSemantics(
                              child: Text(
                                '${_l10n.statsSetNameLabel}: $displayName',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(names.length, (i) {
                            final u = fieldUnitValues[i];
                            final unitLabel = u == '--' ? _s('bez jednotky', 'no unit') : _getUnitSpeech(u);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Semantics(
                                label: _s('Pole ${i + 1}: ${names[i]}, $unitLabel', 'Field ${i + 1}: ${names[i]}, $unitLabel'),
                                child: ExcludeSemantics(child: Text('${i + 1}. ${names[i]} — $unitLabel')),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fieldsDesc,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: _s('Přečíst náhled hlasem', 'Read preview aloud'),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: Text(_s('Přečíst náhled', 'Read preview')),
                      onPressed: () => speakStep(3),
                    ),
                  ),
                ],
              );
            }

            Widget content;
            switch (step) {
              case 0:
                content = buildNameStep();
                break;
              case 1:
                content = buildCountStep();
                break;
              case 2:
                content = buildFieldsStep();
                break;
              case 3:
                content = buildPreviewStep();
                break;
              default:
                content = const SizedBox();
            }

            final canNext = step != 2; // fields step has own next
            return AlertDialog(
              insetPadding: _dialogInsetPadding(),
              semanticLabel: _s('Průvodce vytvořením sady', 'Set creation wizard'),
              title: Semantics(
                header: true,
                child: Text(_s('Průvodce vytvořením sady', 'Set creation wizard')),
              ),
              content: Focus(
                autofocus: true,
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    Future.delayed(const Duration(milliseconds: 400), () => speakStep(step));
                  }
                },
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: content,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _returnFocusToKeyboard();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      for (final c in fieldNameControllers) {
                        try { c.dispose(); } catch (_) {}
                      }
                      try { nameController.dispose(); } catch (_) {}
                      try { countController.dispose(); } catch (_) {}
                    });
                    speak(_s('Průvodce zrušen.', 'Wizard cancelled.'));
                  },
                  child: Text(_l10n.cancel),
                ),
                if (step > 0)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        if (step == 3) {
                          step = 2;
                          currentFieldIndex = fieldCount - 1;
                        } else {
                          step--;
                        }
                      });
                      Future.delayed(const Duration(milliseconds: 250), () => speakStep(step));
                    },
                    child: Text(_s('Zpět', 'Back')),
                  ),
                if (canNext && step < 3)
                  FilledButton(
                    onPressed: () {
                      if (step == 1) {
                        final parsed = _parseNumberAnswer(countController.text);
                        if (parsed == null || parsed < 1 || parsed > 10) {
                          speak(_s('Zadejte číslo 1 až 10.', 'Enter a number 1 to 10.'), force: true);
                          _showAccessibleSnackBar(
                            _s('Zadejte číslo 1 až 10.', 'Enter a number 1 to 10.'),
                            scaffoldContext: this.context,
                          );
                          return;
                        }
                        fieldCount = parsed;
                        // ensure controllers
                        while (fieldNameControllers.length < fieldCount) {
                          fieldNameControllers.add(TextEditingController(text: _s('Pole ${fieldNameControllers.length + 1}', 'Field ${fieldNameControllers.length + 1}')));
                          fieldUnitValues.add('--');
                        }
                        while (fieldNameControllers.length > fieldCount) {
                          fieldNameControllers.removeLast().dispose();
                          fieldUnitValues.removeLast();
                        }
                        currentFieldIndex = 0;
                      }
                      setDialogState(() => step++);
                      Future.delayed(const Duration(milliseconds: 300), () => speakStep(step));
                    },
                    child: Text(_s('Další', 'Next')),
                  ),
                if (step == 3)
                  FilledButton(
                    onPressed: () {
                      try {
                        final rawName = nameController.text.trim();
                        final finalName = rawName.isEmpty ? defaultName : _restoreDiacritics(rawName);
                        // Kontrola duplicity po normalizaci
                        final normNew = _normalizeAnswer(finalName);
                        final duplicate = _statsSets.any((s) => _normalizeAnswer(s.name) == normNew);
                        if (duplicate) {
                          speak(_s('Název $finalName už existuje. Zvolte jiný.', 'Name $finalName already exists. Choose another.'), force: true);
                          // Použij root context (this.context) pro ScaffoldMessenger – dialogový context nemusí mít Scaffold
                          _showAccessibleSnackBar(
                            _s('Název $finalName už existuje.', 'Name $finalName already exists.'),
                            scaffoldContext: this.context,
                          );
                          setDialogState(() => step = 0);
                          Future.delayed(const Duration(milliseconds: 300), () => speakStep(0));
                          return;
                        }
                        // Zajisti konzistenci před generováním
                        while (fieldNameControllers.length < fieldCount) {
                          fieldNameControllers.add(TextEditingController(text: _s('Pole ${fieldNameControllers.length + 1}', 'Field ${fieldNameControllers.length + 1}')));
                          fieldUnitValues.add('--');
                        }
                        while (fieldNameControllers.length > fieldCount) {
                          fieldNameControllers.removeLast().dispose();
                          fieldUnitValues.removeLast();
                        }
                        final fieldNames = fieldNameControllers.map((c) {
                          final t = c.text.trim();
                          return t.isEmpty ? 'Hodnota' : _restoreDiacritics(t);
                        }).toList();
                        // Ochrana proti nesouladu délek
                        if (fieldUnitValues.length < fieldNames.length) {
                          while (fieldUnitValues.length < fieldNames.length) {
                            fieldUnitValues.add('--');
                          }
                        }
                        final fieldUnits = List<String?>.generate(fieldNames.length, (i) => fieldUnitValues[i] == '--' ? null : fieldUnitValues[i]);

                        // ignore: invalid_use_of_protected_member
                        setState(() {
                          _statsSets.add(
                            StatisticsSet(
                              name: finalName,
                              fieldNames: fieldNames,
                              fieldUnits: fieldUnits,
                              records: [],
                            ),
                          );
                          _currentStatsSetIndex = _statsSets.length - 1;
                          _selectedFieldIndex = 0;
                        });
                        _saveStatsData();
                        // Nejdřív zavřít dialog, než vrátit fokus a dispose kontrolerů
                        Navigator.pop(ctx);
                        Future.microtask(() => this._returnFocusToKeyboard());
                        // Dispose až po pop, aby nedošlo k použití po dispose během animace
                        Future.delayed(const Duration(milliseconds: 100), () {
                          for (final c in fieldNameControllers) {
                            try { c.dispose(); } catch (_) {}
                          }
                          try { nameController.dispose(); } catch (_) {}
                          try { countController.dispose(); } catch (_) {}
                        });
                        final fieldsSpoken = fieldNames.join(', ');
                        speak(
                          _s(
                            'Sada $finalName byla vytvořena. Pole: $fieldsSpoken. Hodnoty můžete přidávat tlačítkem M plus.',
                            'Set $finalName was created. Fields: $fieldsSpoken. You can add values using the M+ button.',
                          ),
                          force: true,
                        );
                      } catch (e) {
                        debugPrint('Guided wizard confirm error: $e');
                        _showAccessibleSnackBar(
                          _s('Chyba při vytváření sady: $e', 'Error creating set: $e'),
                          scaffoldContext: this.context,
                        );
                      }
                    },
                    child: Text(_l10n.confirmAction),
                  ),
              ],
            );
          },
        );
      },
    );
    // Úvodní přečtení po otevření
    Future.delayed(const Duration(milliseconds: 600), () => speakStep(0));
  }
}
