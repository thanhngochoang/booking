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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobDraftArea &&
          runtimeType == other.runtimeType &&
          areaId == other.areaId &&
          name == other.name &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(areaId, name, lat, lng);
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

  JobDraft copyWith({
    String? draftId,
    String? specialtyId,
    String? title,
    String? description,
    List<JobReference>? references,
    JobSchedule? schedule,
    JobDraftArea? area,
    JobBudget? budget,
    bool clearBudget = false,
    JobWants? wants,
    AllowedProviders? allowedProviders,
    int? deadlineDays,
  }) {
    return JobDraft(
      draftId: draftId ?? this.draftId,
      specialtyId: specialtyId ?? this.specialtyId,
      title: title ?? this.title,
      description: description ?? this.description,
      references: references ?? this.references,
      schedule: schedule ?? this.schedule,
      area: area ?? this.area,
      budget: clearBudget ? null : (budget ?? this.budget),
      wants: wants ?? this.wants,
      allowedProviders: allowedProviders ?? this.allowedProviders,
      deadlineDays: deadlineDays ?? this.deadlineDays,
    );
  }

  Map<String, dynamic> toJson() => {
    if (draftId != null) 'draftId': draftId,
    'specialtyId': specialtyId,
    'title': title,
    'description': description,
    'references': references.map((r) => r.toJson()).toList(),
    'schedule': schedule.toJson(),
    'area': area.toJson(),
    if (budget != null) 'budget': budget!.toJson(),
    'wants': wants.toJson(),
    'allowedProviders': allowedProviders.code,
    'deadlineDays': deadlineDays,
  };

  factory JobDraft.fromJson(Map<String, dynamic> json) {
    return JobDraft(
      draftId: json['draftId'] as String?,
      specialtyId: json['specialtyId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      references: (json['references'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(JobReference.fromJson)
              .toList() ??
          const [],
      schedule: json['schedule'] is Map<String, dynamic>
          ? JobSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60),
      area: json['area'] is Map<String, dynamic>
          ? JobDraftArea.fromJson(json['area'] as Map<String, dynamic>)
          : const JobDraftArea(areaId: '', name: '', lat: 0, lng: 0),
      budget: json['budget'] is Map<String, dynamic>
          ? JobBudget.fromJson(json['budget'] as Map<String, dynamic>)
          : null,
      wants: json['wants'] is Map<String, dynamic>
          ? JobWants.fromJson(json['wants'] as Map<String, dynamic>)
          : const JobWants(),
      allowedProviders: AllowedProviders.fromCode(json['allowedProviders'] as String?),
      deadlineDays: (json['deadlineDays'] as num?)?.toInt() ?? 3,
    );
  }

  factory JobDraft.fromJob(Job job, {String? draftId, bool resetSchedule = false}) {
    return JobDraft(
      draftId: draftId,
      specialtyId: job.specialtyId,
      title: job.title,
      description: job.description,
      references: List.of(job.references),
      schedule: resetSchedule
          ? const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60)
          : job.schedule,
      area: JobDraftArea(
        areaId: job.area.areaId,
        name: job.area.name,
        lat: job.area.lat,
        lng: job.area.lng,
      ),
      budget: job.budget,
      wants: job.wants,
      allowedProviders: job.allowedProviders,
      deadlineDays: 3,
    );
  }

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
