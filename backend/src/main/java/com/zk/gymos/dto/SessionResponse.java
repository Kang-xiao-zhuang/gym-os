package com.zk.gymos.dto;

import com.zk.gymos.entity.WorkoutSession;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** List row for training history. */
public record SessionResponse(
        UUID id,
        UUID workoutDayId,
        String dayTitle,
        OffsetDateTime startedAt,
        OffsetDateTime finishedAt,
        Integer durationMinutes,
        long totalSets,
        BigDecimal totalVolume,
        long exerciseCount,
        OffsetDateTime createdAt
) {
    public static SessionResponse of(WorkoutSession s, String dayTitle, long totalSets,
                                     BigDecimal totalVolume, long exerciseCount) {
        return new SessionResponse(s.getId(), s.getWorkoutDayId(), dayTitle,
                s.getStartedAt(), s.getFinishedAt(), s.getDurationMinutes(),
                totalSets, totalVolume, exerciseCount, s.getCreatedAt());
    }
}
