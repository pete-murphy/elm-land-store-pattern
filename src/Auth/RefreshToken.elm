module Auth.RefreshToken exposing
    ( RefreshToken
    , fromString, toString
    )

{-| Refresh Token handling - simple opaque identifier for token renewal.

@docs RefreshToken
@docs fromString, toString

-}


{-| Opaque type for refresh tokens - prevents accidental misuse
-}
type RefreshToken
    = RefreshToken String



-- CONSTRUCTORS


{-| Create a refresh token from a string (from API response)
-}
fromString : String -> RefreshToken
fromString =
    RefreshToken


{-| Extract the refresh token string (for API requests)
-}
toString : RefreshToken -> String
toString (RefreshToken token) =
    token
