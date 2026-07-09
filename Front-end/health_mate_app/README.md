# Health Mate Flutter App

Flutter client for Health Mate.

## Symptom Checker Phase 7

The guided symptom checker lives under:

- `lib/features/symptom_checker/domain/entities/assessment_entities.dart`
- `lib/features/symptom_checker/data/datasources/symptom_checker_remote_datasource.dart`
- `lib/features/symptom_checker/data/models/symptom_checker_models.dart`
- `lib/features/symptom_checker/data/repositories/symptom_checker_repository_impl.dart`
- `lib/features/symptom_checker/presentation/providers/`
- `lib/features/symptom_checker/presentation/pages/`
- `lib/features/symptom_checker/presentation/widgets/`

It calls the v2 backend routes:

- `GET /api/v1/ai/categories`
- `GET /api/v1/ai/taxonomy/symptoms?category_id=&lang=`
- `POST /api/v1/ai/assessment?lang=`
- `POST /api/v1/ai/bp-triage?lang=`
- `POST /api/v1/ai/chat/from-assessment?lang=`
- `POST /api/v1/ai/assessment/notify-caregiver?lang=`

The Check tab opens `SymptomCheckerWizardPage` for both patient and caregiver home pages. The
free-text `AiSymptomChatPage` is opened from the result page with assessment context seeded into
the first assistant message.
The symptom picker searches the localized symptom name, stable symptom id, and backend-provided
`synonyms`.

`Notify Caregiver` calls `POST /api/v1/ai/assessment/notify-caregiver` and sends the current
assessment summary to linked caregivers through the existing notification/FCM infrastructure.
The backend also auto-notifies linked caregivers for high-risk guided assessments.

Set the rollout flag to return the Check tab to the old `SymptomCheckerPage` fallback:

```bash
flutter run --dart-define=SYMPTOM_CHECKER_V2_ENABLED=false
```

## Symptom Checker Phase 8 BP Hook

Manual high/critical BP readings created from
`lib/features/vitals/presentation/widgets/bp_card.dart` open
`SymptomCheckerWizardPage(initialBpReading: reading)` after the reading is saved. The wizard:

- selects the `heart_bp` category automatically;
- loads the category symptoms and skips the category-selection step;
- pre-fills systolic, diastolic, and heart-rate fields from the saved `VitalSign`;
- submits through `POST /api/v1/ai/bp-triage?lang=` instead of `/assessment`;
- sends `source_vital_id` so the backend can link the saved `bp_triage` assessment to the
  originating BP reading.

When `SYMPTOM_CHECKER_V2_ENABLED=false`, the same high/critical BP path opens the old
`SymptomCheckerPage` fallback instead of the guided v2 wizard.

## Useful Commands

From `Front-end/health_mate_app/`:

```bash
flutter analyze
flutter test
```

Both commands were passing at Phase-8 sign-off on 2026-07-01.
