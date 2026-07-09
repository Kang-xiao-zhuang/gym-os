package com.zk.gymos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Body of create/update on {@code /api/plans}. */
public record PlanRequest(

        @NotBlank(message = "计划名称不能为空")
        @Size(max = 100, message = "计划名称不能超过 100 个字符")
        String name,

        String description,

        Integer totalWeeks,

        Boolean isActive,

        String icon
) {
}
