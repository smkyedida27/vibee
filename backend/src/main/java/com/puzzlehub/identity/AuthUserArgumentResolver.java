package com.puzzlehub.identity;

import com.puzzlehub.common.ApiException;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import java.util.UUID;

@Component
public class AuthUserArgumentResolver implements HandlerMethodArgumentResolver {

    private final UserRepository users;

    public AuthUserArgumentResolver(UserRepository users) {
        this.users = users;
    }

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.getParameterType().equals(AuthUser.class);
    }

    @Override
    public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mav, NativeWebRequest request,
                                  WebDataBinderFactory binderFactory) {
        AuthUser user = current();
        if (user == null) {
            if (parameter.isOptional() || parameter.hasParameterAnnotation(org.springframework.lang.Nullable.class)) return null;
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Authentication required");
        }
        if (!users.exists(user.id())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "ACCOUNT_DELETED", "Account no longer exists");
        }
        return user;
    }

    static AuthUser current() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof JwtAuthenticationToken jwt) {
            return new AuthUser(UUID.fromString(jwt.getName()));
        }
        return null;
    }
}
