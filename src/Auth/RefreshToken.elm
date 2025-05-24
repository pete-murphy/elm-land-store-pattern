module Auth.RefreshToken exposing
    ( RefreshToken
    , toString
    , decoder
    )

{-| Refresh Token handling - simple opaque identifier for token renewal.

@docs RefreshToken
@docs fromString, toString

-}

import Json.Decode as Decode


{-| Opaque type for refresh tokens - prevents accidental misuse
-}
type RefreshToken
    = RefreshToken String


{-| Create a refresh token from a string (from API response)
-}
decoder : Decode.Decoder RefreshToken
decoder =
    Decode.map RefreshToken Decode.string


{-| Extract the refresh token string (for API requests)
-}
toString : RefreshToken -> String
toString (RefreshToken token) =
    token
