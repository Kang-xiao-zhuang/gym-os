package com.zk.gymos.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Body of create/update on {@code /api/exercises}. */
public record ExerciseRequest(

        @NotBlank(message = "动作名称不能为空")
        @Size(max = 100, message = "动作名称不能超过 100 个字符")
        String name,

        @NotBlank(message = "部位不能为空")
        @Size(max = 50, message = "部位不能超过 50 个字符")
        String bodyPart,

        @Size(max = 50, message = "器械描述不能超过 50 个字符")
        String equipment,

        @Min(value = 1, message = "难度最小为 1")
        Short difficulty,

        String description,

        String imageUrl,

        String videoUrl
) {
}
