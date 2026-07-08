package com.zk.gymos.common;

import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {

    private Integer code;

    private String message;

    private T data;

}