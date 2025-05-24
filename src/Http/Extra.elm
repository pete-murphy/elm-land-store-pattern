module Http.Extra exposing
    ( DetailedError(..)
    , Request
    , detailedErrorToString
    , errorToString
    , expectJsonWithDetailedError
    , is401
    , jsonResolver
    , request
    , requestNoContent
    )

import Http
import Json.Decode as Decode exposing (Decoder)


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus status ->
            "Bad Status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad Body: " ++ body


jsonResolver : Decoder a -> Http.Resolver Http.Error a
jsonResolver decoder =
    Http.stringResolver
        (\response ->
            case response of
                Http.BadUrl_ url ->
                    Err (Http.BadUrl url)

                Http.Timeout_ ->
                    Err Http.Timeout

                Http.NetworkError_ ->
                    Err Http.NetworkError

                Http.BadStatus_ meta _ ->
                    Err (Http.BadStatus meta.statusCode)

                Http.GoodStatus_ _ body ->
                    case Decode.decodeString decoder body of
                        Ok a ->
                            Ok a

                        Err e ->
                            Err (Http.BadBody (Decode.errorToString e))
        )


{-| Like `Http.Error` but:

  - includes `Http.Metadata` and body `String` in the `BadStatus` case and
  - includes the `Decode.Error` in the `BadBody` case

-}
type DetailedError
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Http.Metadata String
    | BadBody Decode.Error


detailedErrorToString : DetailedError -> String
detailedErrorToString error =
    case error of
        BadUrl url ->
            "Bad URL: " ++ url

        Timeout ->
            "Timeout"

        NetworkError ->
            "Network Error"

        BadStatus meta body ->
            "Bad Status: " ++ String.fromInt meta.statusCode ++ " " ++ body

        BadBody decodeError ->
            "Bad Body: " ++ Decode.errorToString decodeError


{-| Like `Http.expectJson` but with `DetailedError` instead of `Http.Error`
-}
expectJsonWithDetailedError : (Result DetailedError a -> msg) -> Decoder a -> Http.Expect msg
expectJsonWithDetailedError toMsg decoder =
    Http.expectStringResponse toMsg
        (resolveWithDetailedError (Decode.decodeString decoder))


resolveWithDetailedError : (String -> Result Decode.Error a) -> Http.Response String -> Result DetailedError a
resolveWithDetailedError toResult response =
    case response of
        Http.BadUrl_ url ->
            Err (BadUrl url)

        Http.Timeout_ ->
            Err Timeout

        Http.NetworkError_ ->
            Err NetworkError

        Http.BadStatus_ metadata body ->
            Err (BadStatus metadata body)

        Http.GoodStatus_ _ body ->
            Result.mapError BadBody (toResult body)


{-| Type alias for the argument to `Http.request`
-}
type alias Request_ a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , expect : Http.Expect a
    , timeout : Maybe Float
    , tracker : Maybe String
    }


{-| The arguments to `Http.request`, but:

  - takes a `Decoder` instead of `Expect`
  - `timeout` and `tracker` are removed

-}
type alias Request a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , decoder : Decoder a
    }


request_ : Request_ msg -> Cmd msg
request_ config =
    Http.request config


request : Request a -> (Result DetailedError a -> msg) -> Cmd msg
request req toMsg =
    request_
        { method = req.method
        , headers = req.headers
        , url = req.url
        , body = req.body
        , expect =
            expectJsonWithDetailedError toMsg req.decoder
        , timeout = Nothing
        , tracker = Nothing
        }


requestNoContent : Request () -> (Result DetailedError () -> msg) -> Cmd msg
requestNoContent req toMsg =
    request_
        { method = req.method
        , headers = req.headers
        , url = req.url
        , body = req.body
        , expect = Http.expectStringResponse toMsg (\_ -> Ok ())
        , timeout = Nothing
        , tracker = Nothing
        }


is401 : DetailedError -> Bool
is401 result =
    case result of
        BadStatus metadata _ ->
            metadata.statusCode == 401

        _ ->
            False
