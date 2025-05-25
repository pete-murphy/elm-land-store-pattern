module Http.Metadata exposing (..)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode


encode : Http.Metadata -> Encode.Value
encode metadata =
    Encode.object
        [ ( "url", Encode.string metadata.url )
        , ( "statusCode", Encode.int metadata.statusCode )
        , ( "statusText", Encode.string metadata.statusText )
        , ( "headers", Encode.dict identity Encode.string metadata.headers )
        ]


decoder : Decoder Http.Metadata
decoder =
    Decode.succeed Http.Metadata
        |> Pipeline.required "url" Decode.string
        |> Pipeline.required "statusCode" Decode.int
        |> Pipeline.required "statusText" Decode.string
        |> Pipeline.required "headers" (Decode.dict Decode.string)
