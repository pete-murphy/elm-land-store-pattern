module Api.Auth exposing
    ( LoginRequest
    , RefreshResponse
    , login, refresh, logout
    )

{-| Authentication API endpoints.

@docs LoginRequest
@docs RefreshResponse
@docs login, refresh, logout

-}

import Auth.AccessToken as AccessToken exposing (AccessToken)
import Auth.Credentials as Credentials exposing (Credentials, LoginResponse)
import Auth.RefreshToken as RefreshToken exposing (RefreshToken)
import Http
import Http.Extra exposing (Request)
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Url.Builder


{-| Login request data
-}
type alias LoginRequest =
    { username : String
    , password : String
    }


{-| Token refresh response
-}
type alias RefreshResponse =
    { accessToken : AccessToken
    , refreshToken : RefreshToken
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
    , decoder = Decode.succeed ()
    }



-- DECODERS


refreshResponseDecoder : Decode.Decoder RefreshResponse
refreshResponseDecoder =
    Decode.succeed RefreshResponse
        |> Pipeline.required "accessToken" AccessToken.decoder
        |> Pipeline.required "refreshToken" RefreshToken.decoder
