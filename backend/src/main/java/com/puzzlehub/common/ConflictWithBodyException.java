package com.puzzlehub.common;

/** 409 whose response body is a domain payload (e.g. the current server copy) instead of a problem. */
public class ConflictWithBodyException extends RuntimeException {

    private final transient Object body;

    public ConflictWithBodyException(Object body) {
        super("conflict");
        this.body = body;
    }

    public Object body() { return body; }
}
