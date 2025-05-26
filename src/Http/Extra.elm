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
import Url.Builder


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


{-| The arguments to `Http.request`, but:

  - takes a `Decoder` instead of `Expect`
  - `timeout` and `tracker` are removed

-}
type alias Request a =
    { method : String
    , headers : List Http.Header
    , path : List String
    , query : List Url.Builder.QueryParameter
    , body : Http.Body
    , decoder : Decoder a
    }


request : Request a -> (Result DetailedError a -> msg) -> Cmd msg
request req toMsg =
    Http.request
        { method = req.method
        , headers = req.headers
        , url = Url.Builder.absolute req.path req.query
        , body = req.body
        , expect =
            DetailedError.expectJson toMsg req.decoder
        , timeout = Nothing
        , tracker = Nothing
        }


requestNoContent : Request () -> (Result DetailedError () -> msg) -> Cmd msg
requestNoContent req toMsg =
    Http.request
        { method = req.method
        , headers = req.headers
        , url = Url.Builder.absolute req.path req.query
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
