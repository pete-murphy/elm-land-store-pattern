module Store exposing (..)

import Dict exposing (Dict)
import Http
import Http.DetailedError as DetailedError exposing (DetailedError)
import Http.Extra exposing (Request)
import Json.Decode
import Loadable exposing (Loadable)
import Paginated
import Url.Builder


type alias Store =
    Dict String (Loadable DetailedError Json.Decode.Value)


type alias Msg =
    { path : List String
    , query : List Url.Builder.QueryParameter
    , headers : List Http.Header
    , decoder : Json.Decode.Decoder Json.Decode.Value
    }


handleRequest :
    Strategy
    -> Msg
    -> Store
    -> ( Store, Maybe (Request Json.Decode.Value) )
handleRequest strategy request store =
    let
        key =
            Url.Builder.absolute request.path request.query

        newStoreUpdate =
            Dict.update key
                (Maybe.map Loadable.toLoading
                    >> Maybe.withDefault Loadable.loading
                    >> Just
                )
                store

        newStoreInsert =
            Dict.insert key Loadable.loading store

        req : Request Json.Decode.Value
        req =
            { method = "GET"
            , headers = request.headers
            , path = request.path
            , query = request.query
            , body = Http.emptyBody
            , decoder = request.decoder
            }
    in
    case ( strategy, Dict.get key store ) of
        ( CacheFirst, Nothing ) ->
            ( newStoreUpdate, Just req )

        ( CacheFirst, _ ) ->
            ( store, Nothing )

        ( NetworkOnly, _ ) ->
            ( newStoreInsert, Just req )

        ( StaleWhileRevalidate, _ ) ->
            ( newStoreUpdate, Just req )


handleRequestPaginated :
    PaginatedStrategy
    -> Msg
    -> Store
    -> ( Store, Maybe (Request Json.Decode.Value) )
handleRequestPaginated strategy request store =
    let
        key =
            Url.Builder.absolute request.path request.query

        lastFetched =
            Dict.get key store
                |> Maybe.andThen Loadable.toMaybe
                |> Maybe.andThen
                    (Json.Decode.decodeValue (Paginated.decoder Json.Decode.value)
                        >> Result.toMaybe
                    )

        maybePaginationParams =
            case ( lastFetched |> Maybe.map .pagination, strategy ) of
                ( Just { hasNextPage, page }, NextPage ) ->
                    if hasNextPage then
                        Just
                            [ Url.Builder.int "page" (page + 1) ]

                    else
                        {- Nothing means we've fetched all pages -}
                        Nothing

                _ ->
                    Just
                        [ Url.Builder.int "page" 1 ]
    in
    case maybePaginationParams of
        Nothing ->
            ( store, Nothing )

        Just paginationParams ->
            let
                newStore : Store
                newStore =
                    Dict.update key
                        (Maybe.map Loadable.toLoading
                            >> Maybe.withDefault Loadable.loading
                            >> Just
                        )
                        store

                req : Request Json.Decode.Value
                req =
                    { method = "GET"
                    , headers = request.headers
                    , path = request.path
                    , query = request.query ++ paginationParams
                    , body = Http.emptyBody
                    , decoder = request.decoder
                    }
            in
            ( newStore, Just req )


handleResponse :
    Msg
    -> Result DetailedError Json.Decode.Value
    -> Store
    -> Store
handleResponse request response store =
    let
        key =
            Url.Builder.absolute request.path request.query
    in
    Dict.insert key (Loadable.fromResult response) store


handleResponsePaginated :
    Msg
    -> Result DetailedError Json.Decode.Value
    -> Store
    -> Store
handleResponsePaginated request response store =
    let
        key =
            Url.Builder.absolute request.path request.query
    in
    Dict.update key
        (Maybe.map
            (\prev ->
                let
                    prevData =
                        prev
                            |> Loadable.andThen
                                (Json.Decode.decodeValue (Paginated.decoder Json.Decode.value)
                                    >> Result.mapError DetailedError.BadBody
                                    >> Result.map .data
                                    >> Loadable.fromResult
                                )
                            |> Loadable.withDefault []

                    apiDataNextPage =
                        Loadable.fromResult response
                in
                apiDataNextPage
                    |> Loadable.andThen
                        (Json.Decode.decodeValue (Paginated.decoder Json.Decode.value)
                            >> Result.mapError DetailedError.BadBody
                            >> Loadable.fromResult
                        )
                    |> Loadable.map
                        (\nextPage ->
                            { nextPage
                                | data =
                                    case nextPage.pagination.page of
                                        1 ->
                                            nextPage.data

                                        _ ->
                                            prevData ++ nextPage.data
                            }
                        )
                    |> Loadable.map (Paginated.encode identity)
            )
            >> Maybe.withDefault Loadable.loading
            >> Just
        )
        store



-- STRATEGY


type Strategy
    = CacheFirst
    | NetworkOnly
    | StaleWhileRevalidate


type PaginatedStrategy
    = NextPage
    | Reset



-- GET VALUES OUT OF THE STORE


get :
    Request a
    -> Store
    -> Loadable DetailedError a
get request store =
    let
        url =
            Url.Builder.absolute request.path request.query

        maybeData =
            Dict.get url store
    in
    maybeData
        |> Maybe.withDefault Loadable.notAsked
        |> Loadable.andThen
            (Json.Decode.decodeValue request.decoder
                >> Result.mapError DetailedError.BadBody
                >> Loadable.fromResult
            )
