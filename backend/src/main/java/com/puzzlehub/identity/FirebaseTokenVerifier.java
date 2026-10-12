package com.puzzlehub.identity;

/** Verifies a Firebase ID token and returns the Firebase user id ({@code sub}). */
public interface FirebaseTokenVerifier {

    String verify(String idToken);
}
