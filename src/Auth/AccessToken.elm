module Auth.AccessToken exposing
    ( AccessToken
    , toString, decoder
    , isExpired, expiresAt, decode
    , httpHeader
    )

{-| JWT Access Token handling with expiration and decoding capabilities.

@docs AccessToken
@docs toString, decoder
@docs isExpired, expiresAt, decode
@docs httpHeader

-}

import Http
import Json.Decode as Decode
import Jwt
import Time


{-| Opaque type for access tokens - prevents accidental misuse
-}
type AccessToken
    = AccessToken String


{-| Extract the token string (for storage, debugging, etc.)
-}
toString : AccessToken -> String
toString (AccessToken token) =
    token


decoder : Decode.Decoder AccessToken
decoder =
    Decode.map AccessToken Decode.string



-- JWT FUNCTIONALITY


{-| Check if an access token is expired
-}
isExpired : Time.Posix -> AccessToken -> Bool
isExpired currentTime token =
    case expiresAt token of
        Ok expTime ->
            Time.posixToMillis currentTime > (expTime * 1000)

        Err _ ->
            -- If we can't decode the expiration, assume it's expired
            True


{-| Get the expiration time from a token (Unix timestamp)
-}
expiresAt : AccessToken -> Result Jwt.JwtError Int
expiresAt (AccessToken token) =
    Jwt.decodeToken (Decode.field "exp" Decode.int) token


{-| Decode any field from a JWT token
-}
decode : Decode.Decoder a -> AccessToken -> Result Jwt.JwtError a
decode decoder_ (AccessToken token) =
    Jwt.decodeToken decoder_ token



-- HTTP


{-| Create an Authorization header with the access token
-}
httpHeader : AccessToken -> Http.Header
httpHeader (AccessToken token) =
    Http.header "Authorization" ("Bearer " ++ token)
