package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

/**
 * A single exercise in the shared library, mapped to {@code public.exercises}.
 * {@link #imageUrl}/{@link #videoUrl} point at media in Supabase Storage.
 */
@Getter
@Setter
@Entity
@Table(name = "exercises")
public class Exercise extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 100)
    private String name;

    /** Target body part, free text (胸 / 背 / 腿 …). */
    @Column(name = "body_part", nullable = false, length = 50)
    private String bodyPart;

    /** Equipment used (杠铃 / 哑铃 / 器械 / 自重 …). */
    @Column(length = 50)
    private String equipment;

    /** 1 (easiest) .. n. */
    @Column
    private Short difficulty = 1;

    @Column(columnDefinition = "text")
    private String description;

    /** Demo image/GIF URL in Supabase Storage. */
    @Column(name = "image_url", columnDefinition = "text")
    private String imageUrl;

    /** Demo video URL in Supabase Storage. */
    @Column(name = "video_url", columnDefinition = "text")
    private String videoUrl;
}
