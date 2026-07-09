package com.zk.gymos.dto;

import com.zk.gymos.entity.User;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Public profile view of a user. */
public record UserResponse(
        UUID id,
        String nickname,
        String email,
        String avatar,
        OffsetDateTime createdAt
) {
    public static UserResponse of(User u) {
        return new UserResponse(u.getId(), u.getNickname(), u.getEmail(), u.getAvatar(), u.getCreatedAt());
    }
}
