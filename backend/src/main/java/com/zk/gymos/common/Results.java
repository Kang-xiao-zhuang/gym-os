package com.zk.gymos.common;

public class Results {

    public static <T> Result<T> success(T data) {

        return new Result<>(200, "success", data);

    }

    public static Result<Void> success() {

        return new Result<>(200, "success", null);

    }

    public static Result<Void> fail(String msg) {

        return new Result<>(500, msg, null);

    }

}