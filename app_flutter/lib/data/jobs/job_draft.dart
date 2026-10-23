// lib/data/jobs/job_draft.dart
//
// JobDraft for creating and updating jobs (S15.01).
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/jobs/job.dart';

@immutable
class JobDraftArea {
  const JobDraftArea({
    required this.areaId,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String areaId;
  final String name;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'name': name,
    'lat': lat,
    'lng': lng,
  };

  factory JobDraftArea.fromJson(Map<String, dynamic> json) => JobDraftArea(
    areaId: json['areaId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
  );
}

@immutable
class JobDraft {
  const JobDraft({
    this.draftId,
    required this.specialtyId,
    required this.title,
    required this.description,
    this.references = const [],
    required this.schedule,
    required this.area,
    this.budget,
    this.wants = const JobWants(),
    this.allowedProviders = AllowedProviders.all,
    this.deadlineDays = 3,
  });

  final String? draftId;
  final String specialtyId;
  final String title;
  final String description;
  final List<JobReference> references;
  final JobSchedule schedule;
  final JobDraftArea area;
  final JobBudget? budget;
  final JobWants wants;
  final AllowedProviders allowedProviders;
  final int deadlineDays;

  Map<String, dynamic> toCreatePayload() => {
    'specialtyId': specialtyId,
    'title': title,
    'description': description,
    'references': references.map((r) => r.toJson()).toList(),
    'schedule': schedule.toJson(),
    'area': area.toJson(),
    'budget': budget?.toJson(),
    'wants': wants.toJson(),
    'allowedProviders': allowedProviders.code,
    'deadlineDays': deadlineDays,
  };

  Map<String, dynamic> toUpdatePayload(String jobId) => {
    'jobId': jobId,
    'specialtyId': specialtyId,
    'title': title,
    'description': description,
    'references': references.map((r) => r.toJson()).toList(),
    'schedule': schedule.toJson(),
    'area': area.toJson(),
    'budget': budget?.toJson(),
    'wants': wants.toJson(),
    'allowedProviders': allowedProviders.code,
  };
}
