module Auth.Credentials exposing
    ( Credentials, LoginResponse
    , create, user, accessToken, refreshToken
    , updateTokens
    , httpHeaders, isExpired
    , loginResponseDecoder
    )

{-| Authentication credentials management.

@docs Credentials, LoginResponse
@docs create, user, accessToken, refreshToken
@docs updateTokens

@docs httpHeaders, isExpired
@docs loginResponseDecoder

-}

import Auth.AccessToken as AccessToken exposing (AccessToken)
import Auth.RefreshToken as RefreshToken exposing (RefreshToken)
import Auth.User as User exposing (User)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Time


{-| Authentication credentials containing user and tokens
-}
type Credentials
    = Credentials CredentialsData


type alias CredentialsData =
    { user : User
    , accessToken : AccessToken
    , refreshToken : RefreshToken
    }


{-| Login response from the API
-}
type alias LoginResponse =
    { user : User
    , accessToken : AccessToken
    , refreshToken : RefreshToken
    }



-- CONSTRUCTORS


{-| Create credentials from a login response
-}
create : LoginResponse -> Credentials
create response =
    Credentials
        { user = response.user
        , accessToken = response.accessToken
        , refreshToken = response.refreshToken
        }


{-| JSON decoder for login response
-}
loginResponseDecoder : Decoder LoginResponse
loginResponseDecoder =
    Decode.succeed LoginResponse
        |> Pipeline.required "user" User.decoder
        |> Pipeline.required "accessToken" AccessToken.decoder
        |> Pipeline.required "refreshToken" RefreshToken.decoder



-- UPDATE


updateTokens :
    AccessToken
    -> RefreshToken
    -> Credentials
    -> Credentials
updateTokens accessToken_ refreshToken_ (Credentials data) =
    Credentials
        { data
            | accessToken = accessToken_
            , refreshToken = refreshToken_
        }



-- GETTERS


{-| Get the authenticated user
-}
user : Credentials -> User
user (Credentials data) =
    data.user


{-| Get the access token
-}
accessToken : Credentials -> AccessToken
accessToken (Credentials data) =
    data.accessToken


{-| Get the refresh token
-}
refreshToken : Credentials -> RefreshToken
refreshToken (Credentials data) =
    data.refreshToken



-- HTTP


{-| Generate HTTP headers for authenticated requests
-}
httpHeaders : Credentials -> List Http.Header
httpHeaders credentials =
    [ AccessToken.httpHeader (accessToken credentials) ]



-- TOKEN VALIDATION


{-| Check if the access token is expired
-}
isExpired : Time.Posix -> Credentials -> Bool
isExpired currentTime credentials =
    AccessToken.isExpired currentTime (accessToken credentials)
