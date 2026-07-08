package com.zk.gymos.entity;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Shared audit columns. Only extend this on tables that actually have BOTH
 * created_at AND updated_at (with ddl-auto=validate a missing column fails startup).
 */
@Getter
@Setter
@MappedSuperclass
public abstract class BaseEntity {

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /** JPA calls this right before the first INSERT. */
    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) createdAt = now;
        updatedAt = now;
    }

    /** JPA calls this right before every UPDATE. */
    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
