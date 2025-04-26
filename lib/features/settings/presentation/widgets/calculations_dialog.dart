import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class CalculationsDialog extends StatefulWidget {
  final SettingsBloc settingsBloc;
  final ProfileBloc profileBloc;
  final HomeBloc homeBloc;
  final DiaryBloc diaryBloc;
  final CalendarDayBloc calendarDayBloc;

  const CalculationsDialog({
    super.key,
    required this.settingsBloc,
    required this.profileBloc,
    required this.homeBloc,
    required this.diaryBloc,
    required this.calendarDayBloc,
  });

  @override
  State<CalculationsDialog> createState() => _CalculationsDialogState();
}

class _CalculationsDialogState extends State<CalculationsDialog> {
  // Controllers for direct text input
  late TextEditingController _kcalController;
  late TextEditingController _carbsGramController;
  late TextEditingController _proteinGramController;
  late TextEditingController _fatGramController;

  // Base kcal value - will be used to calculate macro grams
  double _baseKcal = 2000; // Default value

  // Macros percentages
  double _carbsPctSelection = 50; // Default 50%
  double _proteinPctSelection = 15; // Default 15%
  double _fatPctSelection = 35; // Default 35%

  // Macros in grams
  double _carbsGram = 250; // Default, will be calculated
  double _proteinGram = 75; // Default, will be calculated
  double _fatGram = 78; // Default, will be calculated

  // Constants for macronutrient calorie content
  static const double _carbsCaloriesPerGram = 4.0;
  static const double _proteinCaloriesPerGram = 4.0;
  static const double _fatCaloriesPerGram = 9.0;

  @override
  void initState() {
    super.initState();
    _kcalController = TextEditingController(text: "0");
    _carbsGramController = TextEditingController();
    _proteinGramController = TextEditingController();
    _fatGramController = TextEditingController();
  }

  @override
  void dispose() {
    _kcalController.dispose();
    _carbsGramController.dispose();
    _proteinGramController.dispose();
    _fatGramController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeValues();
  }

  void _initializeValues() async {
    try {
      // Get user's current calorie adjustment from settings
      final kcalAdjustment = await widget.settingsBloc.getKcalAdjustment() * 1.0;
      final userCarbsPct = await widget.settingsBloc.getUserCarbGoalPct() ?? 0.5;
      final userProteinPct = await widget.settingsBloc.getUserProteinGoalPct() ?? 0.15;
      final userFatPct = await widget.settingsBloc.getUserFatGoalPct() ?? 0.35;

      // Since we can't access TDEE directly, we'll estimate using the current settings
      _baseKcal = 0; // Default estimate

      if (mounted) {
        setState(() {
          _kcalController.text = kcalAdjustment.toInt().toString();

          _carbsPctSelection = userCarbsPct * 100;
          _proteinPctSelection = userProteinPct * 100;
          _fatPctSelection = userFatPct * 100;

          // Calculate macros in grams
          _updateMacroGrams();
        });
      }
    } catch (e) {
      debugPrint('Error initializing values: $e');
    }
  }

  void _updateMacroGrams() {
    // Calculate total calories (base + adjustment)
    double totalKcal = _baseKcal + (double.tryParse(_kcalController.text) ?? 0);

    // Calculate macros in grams based on percentages and total calories
    _carbsGram = (totalKcal * (_carbsPctSelection / 100)) / _carbsCaloriesPerGram;
    _proteinGram = (totalKcal * (_proteinPctSelection / 100)) / _proteinCaloriesPerGram;
    _fatGram = (totalKcal * (_fatPctSelection / 100)) / _fatCaloriesPerGram;

    // Update text controllers
    _carbsGramController.text = _carbsGram.toStringAsFixed(0);
    _proteinGramController.text = _proteinGram.toStringAsFixed(0);
    _fatGramController.text = _fatGram.toStringAsFixed(0);
  }

  void _updateMacroPercentagesFromGrams() {
    // Get total calories
    double totalKcal = _baseKcal + (double.tryParse(_kcalController.text) ?? 0);

    // Calculate calories from each macro
    double carbsGram = double.tryParse(_carbsGramController.text) ?? 0;
    double proteinGram = double.tryParse(_proteinGramController.text) ?? 0;
    double fatGram = double.tryParse(_fatGramController.text) ?? 0;

    double carbsCal = carbsGram * _carbsCaloriesPerGram;
    double proteinCal = proteinGram * _proteinCaloriesPerGram;
    double fatCal = fatGram * _fatCaloriesPerGram;

    // Calculate percentages
    if (totalKcal > 0) {
      _carbsPctSelection = (carbsCal / totalKcal) * 100;
      _proteinPctSelection = (proteinCal / totalKcal) * 100;
      _fatPctSelection = (fatCal / totalKcal) * 100;
    }
  }

  @override
  Widget build(BuildContextContext) {
    // Calculate total percentage
    double totalPct = _carbsPctSelection + _proteinPctSelection + _fatPctSelection;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              S.of(context).settingsCalculationsLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            child: Text(S.of(context).buttonResetLabel),
            onPressed: () {
              setState(() {
                _kcalController.text = "0";
                _carbsPctSelection = 50;
                _proteinPctSelection = 15;
                _fatPctSelection = 35;
                _updateMacroGrams();
              });
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField(
              isExpanded: true,
              decoration: InputDecoration(
                enabled: false,
                filled: false,
                labelText: S.of(context).calculationsTDEELabel,
              ),
              items: [
                DropdownMenuItem(
                  child: Text(
                    '${S.of(context).calculationsTDEEIOM2006Label} ${S.of(context).calculationsRecommendedLabel} (${_baseKcal.toStringAsFixed(0)} ${S.of(context).kcalLabel})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: null,
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).dailyKcalAdjustmentLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _kcalController,
              decoration: InputDecoration(
                labelText: S.of(context).kcalLabel,
                border: const OutlineInputBorder(),
                suffixText: S.of(context).kcalLabel,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                setState(() {
                  _updateMacroGrams();
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).macroDistributionLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Total: ${totalPct.round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildMacroInputs(
              S.of(context).carbsLabel,
              _carbsPctSelection,
              _carbsGram,
              Colors.orange,
              _carbsGramController,
                  (value) {
                setState(() {
                  _carbsPctSelection = value;
                  _updateMacroGrams();
                });
              },
                  (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _carbsGram = double.tryParse(value) ?? 0;
                    _updateMacroPercentagesFromGrams();
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            _buildMacroInputs(
              S.of(context).proteinLabel,
              _proteinPctSelection,
              _proteinGram,
              Colors.blue,
              _proteinGramController,
                  (value) {
                setState(() {
                  _proteinPctSelection = value;
                  _updateMacroGrams();
                });
              },
                  (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _proteinGram = double.tryParse(value) ?? 0;
                    _updateMacroPercentagesFromGrams();
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            _buildMacroInputs(
              S.of(context).fatLabel,
              _fatPctSelection,
              _fatGram,
              Colors.green,
              _fatGramController,
                  (value) {
                setState(() {
                  _fatPctSelection = value;
                  _updateMacroGrams();
                });
              },
                  (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _fatGram = double.tryParse(value) ?? 0;
                    _updateMacroPercentagesFromGrams();
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(S.of(context).dialogCancelLabel),
        ),
        TextButton(
          onPressed: () {
            _saveCalculationSettings();
          },
          child: Text(S.of(context).dialogOKLabel),
        ),
      ],
    );
  }

  Widget _buildMacroInputs(
      String label,
      double percentage,
      double grams,
      Color color,
      TextEditingController gramController,
      ValueChanged<double> onSliderChanged,
      ValueChanged<String> onGramChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${percentage.round()}% (${grams.toStringAsFixed(0)}g)'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: color,
                  thumbColor: color,
                  inactiveTrackColor: color.withAlpha(50),
                ),
                child: Slider(
                  min: 0,
                  max: 100,
                  value: percentage.clamp(0, 100),
                  divisions: 100,
                  onChanged: (value) {
                    onSliderChanged(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: gramController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  suffixText: 'g',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: onGramChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveCalculationSettings() {
    // Save the calorie offset from text field
    double kcalAdjustment = double.tryParse(_kcalController.text) ?? 0;
    widget.settingsBloc.setKcalAdjustment(kcalAdjustment);

    // Convert percentages to decimal for storage
    double carbsPct = _carbsPctSelection / 100;
    double proteinPct = _proteinPctSelection / 100;
    double fatPct = _fatPctSelection / 100;

    widget.settingsBloc.setMacroGoals(
        _carbsPctSelection, _proteinPctSelection, _fatPctSelection);

    widget.settingsBloc.add(LoadSettingsEvent());
    // Update other blocs that need the new calorie value
    widget.profileBloc.add(LoadProfileEvent());
    widget.homeBloc.add(LoadItemsEvent());

    // Update tracked day entity
    widget.settingsBloc.updateTrackedDay(DateTime.now());
    widget.diaryBloc.add(LoadDiaryYearEvent());
    widget.calendarDayBloc.add(RefreshCalendarDayEvent());

    Navigator.of(context).pop();
  }
}