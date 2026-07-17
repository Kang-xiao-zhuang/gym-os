package com.zk.gymos.dto;

/** Summary of an import run: how many sessions were created, skipped as duplicates, and new exercises auto-created. */
public record ImportResult(int imported, int skipped, int exercisesCreated) {}
