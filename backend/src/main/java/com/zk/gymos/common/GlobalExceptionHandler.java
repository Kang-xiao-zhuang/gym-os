package com.zk.gymos.common;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

/**
 * Turns exceptions into the project's uniform {@link Result} response so the app never
 * receives a raw Spring error page. Every handler returns HTTP 200 with the real status
 * carried in {@code Result.code} — matching the {@link Results} convention.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** Expected business failures thrown by the service layer → their own code. */
    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusiness(BusinessException e) {
        return new Result<>(e.getCode(), e.getMessage(), null);
    }

    /** Bean-validation failures (@Valid on a request body) → 400 + the first field message. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldError() != null
                ? e.getBindingResult().getFieldError().getDefaultMessage()
                : "参数校验失败";
        return new Result<>(ResultCode.VALIDATE_FAILED, msg, null);
    }

    /** Explicitly thrown status errors, e.g. throw new ResponseStatusException(NOT_FOUND, "..."). */
    @ExceptionHandler(ResponseStatusException.class)
    public Result<Void> handleStatus(ResponseStatusException e) {
        return new Result<>(e.getStatusCode().value(), e.getReason(), null);
    }

    /** Anything unexpected → 500. (Don't expose internals in production later.) */
    @ExceptionHandler(Exception.class)
    public Result<Void> handleOther(Exception e) {
        return new Result<>(ResultCode.FAIL, e.getMessage(), null);
    }
}
