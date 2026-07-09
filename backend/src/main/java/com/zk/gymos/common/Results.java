package com.zk.gymos.common;

public class Results {

    public static <T> Result<T> success(T data) {
        return new Result<>(ResultCode.SUCCESS, "success", data);
    }

    public static Result<Void> success() {
        return new Result<>(ResultCode.SUCCESS, "success", null);
    }

    public static Result<Void> fail(String msg) {
        return new Result<>(ResultCode.FAIL, msg, null);
    }

    public static Result<Void> fail(int code, String msg) {
        return new Result<>(code, msg, null);
    }

}
