module Api.Auth exposing
    ( LoginRequest, RefreshRequest
    , RefreshResponse
    , login, refresh, logout, verify
    )

{-| Authentication API endpoints.

@docs LoginRequest, RefreshRequest
@docs RefreshResponse
@docs login, refresh, logout, verify

-}

import Auth.Credentials as Credentials exposing (Credentials, LoginResponse)
import Auth.RefreshToken as RefreshToken
import Auth.User as User exposing (User)
import Http
import Http.Extra exposing (Request)
import Json.Decode as Decode
import Json.Encode as Encode
import Url.Builder


{-| Login request data
-}
type alias LoginRequest =
    { username : String
    , password : String
    }


{-| Refresh token request
-}
type alias RefreshRequest =
    { refreshToken : String
    }


{-| Token refresh response
-}
type alias RefreshResponse =
    { accessToken : String
    , expiresIn : Int
    }



-- HTTP REQUESTS


{-| Login with username and password
-}
login : LoginRequest -> Request LoginResponse
login request =
    { method = "POST"
    , headers = []
    , url = Url.Builder.absolute [ "api", "auth", "login" ] []
    , body =
        Http.jsonBody
            (Encode.object
                [ ( "username", Encode.string request.username )
                , ( "password", Encode.string request.password )
                ]
            )
    , decoder = Credentials.loginResponseDecoder
    }


{-| Refresh an expired access token
-}
refresh : Credentials -> Request RefreshResponse
refresh credentials =
    { method = "POST"
    , headers = []
    , url = Url.Builder.absolute [ "api", "auth", "refresh" ] []
    , body =
        Http.jsonBody
            (Encode.object
                [ ( "refreshToken"
                  , Encode.string
                        (RefreshToken.toString
                            (Credentials.refreshToken credentials)
                        )
                  )
                ]
            )
    , decoder = refreshResponseDecoder
    }


{-| Logout and revoke refresh token
-}
logout : Credentials -> Request ()
logout credentials =
    { method = "POST"
    , headers = []
    , url = Url.Builder.absolute [ "api", "auth", "logout" ] []
    , body =
        Http.jsonBody
            (Encode.object
                [ ( "refreshToken"
                  , Encode.string
                        (RefreshToken.toString
                            (Credentials.refreshToken credentials)
                        )
                  )
                ]
            )
    , decoder = Decode.map (\_ -> ()) (Decode.field "message" Decode.string)
    }


{-| Verify current access token
-}
verify : Credentials -> Request User
verify credentials =
    { method = "GET"
    , headers = Credentials.httpHeaders credentials
    , url = Url.Builder.absolute [ "api", "auth", "verify" ] []
    , body = Http.emptyBody
    , decoder = Decode.field "user" User.decoder
    }



-- DECODERS


refreshResponseDecoder : Decode.Decoder RefreshResponse
refreshResponseDecoder =
    Decode.map2 RefreshResponse
        (Decode.field "accessToken" Decode.string)
        (Decode.field "expiresIn" Decode.int)
