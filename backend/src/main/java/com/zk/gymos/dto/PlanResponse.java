package com.zk.gymos.dto;

import com.zk.gymos.entity.WorkoutPlan;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PlanResponse(
        UUID id,
        String name,
        String description,
        Integer totalWeeks,
        Boolean isActive,
        String icon,
        OffsetDateTime createdAt
) {
    public static PlanResponse of(WorkoutPlan p) {
        return new PlanResponse(p.getId(), p.getName(), p.getDescription(),
                p.getTotalWeeks(), p.getIsActive(), p.getIcon(), p.getCreatedAt());
    }
}
