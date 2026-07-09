package com.zk.gymos.dto;

import com.zk.gymos.entity.WorkoutDay;

import java.util.UUID;

public record DayResponse(
        UUID id,
        Integer weekNo,
        Integer dayNo,
        String title
) {
    public static DayResponse of(WorkoutDay d) {
        return new DayResponse(d.getId(), d.getWeekNo(), d.getDayNo(), d.getTitle());
    }
}
