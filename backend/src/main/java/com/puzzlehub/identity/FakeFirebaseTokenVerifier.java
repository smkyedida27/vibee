package com.puzzlehub.identity;

import com.puzzlehub.common.ApiException;
import org.springframework.http.HttpStatus;

/** Dev/test only: accepts tokens of the form {@code fake:<uid>}. Refused in the prod profile. */
public class FakeFirebaseTokenVerifier implements FirebaseTokenVerifier {

    @Override
    public String verify(String idToken) {
        if (idToken != null && idToken.startsWith("fake:") && idToken.length() > 5 && idToken.length() <= 128) {
            return idToken.substring(5);
        }
        throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_ID_TOKEN", "Firebase ID token is invalid");
    }
}
