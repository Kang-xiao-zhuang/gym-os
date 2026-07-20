package com.zk.gymos.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * The next training day to do in the active plan, chosen by rolling rotation
 * (the day after the one you last completed, cycling). Null when there is no
 * active plan or it has no days. Adapts to any plan and any training cadence
 * with zero per-user configuration.
 */
public record NextUpResponse(
        UUID planId,
        String planName,
        String planIcon,
        UUID dayId,
        String dayTitle,
        Integer dayNo,
        List<DayExerciseResponse> exercises,
        String lastDoneTitle,
        OffsetDateTime lastDoneAt
) {}
