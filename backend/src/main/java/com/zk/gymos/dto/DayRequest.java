package com.zk.gymos.dto;

import jakarta.validation.constraints.Size;

/** Body of {@code POST /api/plans/{planId}/days}. weekNo/dayNo optional (auto-assigned). */
public record DayRequest(

        Integer weekNo,

        Integer dayNo,

        @Size(max = 100, message = "标题不能超过 100 个字符")
        String title
) {
}
