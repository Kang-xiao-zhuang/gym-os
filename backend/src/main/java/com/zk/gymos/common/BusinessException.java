package com.zk.gymos.common;

import lombok.Getter;

/**
 * Thrown by the service layer for expected, recoverable failures (bad input, not found,
 * duplicate, etc.). {@link GlobalExceptionHandler} maps it to a {@link Result} carrying
 * {@link #code}. Use this instead of returning error Results by hand.
 */
@Getter
public class BusinessException extends RuntimeException {

    private final int code;

    public BusinessException(int code, String message) {
        super(message);
        this.code = code;
    }

    /** Shortcut for the common "business rule violated" case (HTTP 400). */
    public static BusinessException of(String message) {
        return new BusinessException(ResultCode.VALIDATE_FAILED, message);
    }

    public static BusinessException notFound(String message) {
        return new BusinessException(ResultCode.NOT_FOUND, message);
    }
}
