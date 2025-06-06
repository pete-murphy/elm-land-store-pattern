module Http.DetailedError exposing (..)

{-| Like `Http.Error` but:

  - includes `Http.Metadata` and body `String` in the `BadStatus` case and
  - includes the `Decode.Error` in the `BadBody` case

-}

import Http
import Http.Metadata
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type DetailedError
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Http.Metadata String
    | BadBody Decode.Error


toString : DetailedError -> String
toString error =
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


encode : DetailedError -> Encode.Value
encode error =
    case error of
        BadUrl url ->
            Encode.object
                [ ( "type", Encode.string "BadUrl" )
                , ( "url", Encode.string url )
                ]

        Timeout ->
            Encode.object
                [ ( "type", Encode.string "Timeout" )
                ]

        NetworkError ->
            Encode.object
                [ ( "type", Encode.string "NetworkError" )
                ]

        BadStatus meta body ->
            Encode.object
                [ ( "type", Encode.string "BadStatus" )
                , ( "value"
                  , Encode.object
                        [ ( "metadata", Http.Metadata.encode meta )
                        , ( "body", Encode.string body )
                        ]
                  )
                ]

        BadBody decodeError ->
            Encode.object
                [ ( "type", Encode.string "BadBody" )
                , ( "value"
                  , Encode.object
                        [ ( "decodeError", Encode.string (Decode.errorToString decodeError) )
                        ]
                  )
                ]


{-| Like `Http.expectJson` but with `DetailedError` instead of `Http.Error`
-}
expectJson : (Result DetailedError a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder_ =
    Http.expectStringResponse toMsg
        (resolve (Decode.decodeString decoder_))


resolve : (String -> Result Decode.Error a) -> Http.Response String -> Result DetailedError a
resolve toResult response =
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
