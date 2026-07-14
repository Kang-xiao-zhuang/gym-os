package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

/** Per-session history of one exercise for a small trend chart. */
public record ExerciseTrendResponse(
        List<Point> points
) {
    /** One session: date, top weight that day, total volume, and best estimated 1RM (Epley). */
    public record Point(OffsetDateTime date, BigDecimal maxWeight, BigDecimal volume, BigDecimal est1rm) {}
}
