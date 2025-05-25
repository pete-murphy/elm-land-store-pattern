module Http.Extra exposing
    ( Request
    , errorToString
    , is401
    , jsonResolver
    , request
    , requestNoContent
    )

import Http
import Http.DetailedError as DetailedError exposing (DetailedError)
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
            DetailedError.expectJson toMsg req.decoder
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
        DetailedError.BadStatus metadata _ ->
            metadata.statusCode == 401

        _ ->
            False
