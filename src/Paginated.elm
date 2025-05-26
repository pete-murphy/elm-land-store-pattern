module Paginated exposing (..)

import Json.Decode
import Json.Decode.Pipeline
import Json.Encode


type alias Paginated a =
    { data : List a
    , pagination : Pagination
    }


type alias Pagination =
    { page : Int
    , limit : Int
    , totalPages : Int
    , totalCount : Int
    , hasNextPage : Bool
    , hasPreviousPage : Bool
    }


decoder : Json.Decode.Decoder a -> Json.Decode.Decoder (Paginated a)
decoder decoderA =
    Json.Decode.succeed Paginated
        |> Json.Decode.Pipeline.required "data" (Json.Decode.list decoderA)
        |> Json.Decode.Pipeline.required "pagination" paginationDecoder


encode : (a -> Json.Encode.Value) -> Paginated a -> Json.Encode.Value
encode encodeA paginated =
    Json.Encode.object
        [ ( "data", Json.Encode.list encodeA paginated.data )
        , ( "pagination", paginationEncode paginated.pagination )
        ]


paginationEncode : Pagination -> Json.Encode.Value
paginationEncode pagination =
    Json.Encode.object
        [ ( "page", Json.Encode.int pagination.page )
        , ( "limit", Json.Encode.int pagination.limit )
        , ( "totalPages", Json.Encode.int pagination.totalPages )
        , ( "totalCount", Json.Encode.int pagination.totalCount )
        , ( "hasNextPage", Json.Encode.bool pagination.hasNextPage )
        , ( "hasPreviousPage", Json.Encode.bool pagination.hasPreviousPage )
        ]


paginationDecoder : Json.Decode.Decoder Pagination
paginationDecoder =
    Json.Decode.succeed Pagination
        |> Json.Decode.Pipeline.required "page" Json.Decode.int
        |> Json.Decode.Pipeline.required "limit" Json.Decode.int
        |> Json.Decode.Pipeline.required "totalPages" Json.Decode.int
        |> Json.Decode.Pipeline.required "totalCount" Json.Decode.int
        |> Json.Decode.Pipeline.required "hasNextPage" Json.Decode.bool
        |> Json.Decode.Pipeline.required "hasPreviousPage" Json.Decode.bool


merge : Paginated a -> Paginated a -> Paginated a
merge previous next =
    { data = previous.data ++ next.data
    , pagination = next.pagination
    }
