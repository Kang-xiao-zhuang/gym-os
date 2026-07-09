package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Full session grouped by exercise, with each exercise's logged sets. */
public record SessionDetailResponse(
        UUID id,
        String dayTitle,
        OffsetDateTime startedAt,
        OffsetDateTime finishedAt,
        Integer durationMinutes,
        long totalSets,
        BigDecimal totalVolume,
        List<ExerciseLog> exercises
) {
    public record ExerciseLog(UUID exerciseId, String name, String bodyPart, List<SetLog> sets) {}

    public record SetLog(Integer setNo, BigDecimal weight, Integer reps) {}
}
