module Store exposing (..)

import Dict exposing (Dict)
import Http
import Http.Extra
import Json.Decode
import Json.Encode as Encode
import Loadable exposing (Loadable)
import Paginated exposing (Paginated)
import Result.Extra
import Store.Request as Request exposing (Key, Request)
import Url.Builder


type alias Store a =
    Dict Key (Loadable Http.Extra.DetailedError a)


handleRequest :
    Strategy
    -> Request.Msg ()
    -> Store Encode.Value
    -> ( Store Encode.Value, Maybe (Http.Extra.Request Encode.Value) )
handleRequest strategy request store =
    let
        key =
            Request.key request

        newStoreUpdate =
            Dict.update key
                (Maybe.map Loadable.toLoading
                    >> Maybe.withDefault Loadable.loading
                    >> Just
                )
                store

        newStoreInsert =
            Dict.insert key Loadable.loading store

        req : Http.Extra.Request Encode.Value
        req =
            { method = "GET"
            , headers = Request.headers request
            , url =
                Url.Builder.absolute (Request.pathSegments request)
                    (Request.queryParams request)
            , body = Http.emptyBody
            , decoder = Json.Decode.value
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
    -> Request.Msg Paginated.Config
    -> Store (Paginated Encode.Value)
    -> ( Store (Paginated Encode.Value), Maybe (Http.Extra.Request (Paginated Encode.Value)) )
handleRequestPaginated strategy request store =
    let
        key =
            Request.key request

        config =
            Request.config request

        lastFetched =
            Dict.get key store
                |> Maybe.andThen Loadable.toMaybe
                |> Debug.log "lastFetched"

        maybePaginationParams =
            case ( lastFetched |> Maybe.map .pagination, strategy ) of
                ( Just { hasNextPage, page }, NextPage ) ->
                    if hasNextPage then
                        Just
                            [ Url.Builder.int "page" (page + 1)
                            , Url.Builder.int "per_page" config.perPage
                            ]

                    else
                        {- Nothing means we've fetched all pages -}
                        Nothing

                _ ->
                    Just
                        [ Url.Builder.int "page" 1
                        , Url.Builder.int "per_page" config.perPage
                        ]
    in
    case maybePaginationParams of
        Nothing ->
            ( store, Nothing )

        Just paginationParams ->
            let
                newStore : Store (Paginated Encode.Value)
                newStore =
                    Dict.update key
                        (Maybe.map Loadable.toLoading
                            >> Maybe.withDefault Loadable.loading
                            >> Just
                        )
                        store

                req : Http.Extra.Request (Paginated Encode.Value)
                req =
                    { method = "GET"
                    , headers = Request.headers request
                    , url =
                        Url.Builder.absolute (Request.pathSegments request)
                            (Request.queryParams request ++ paginationParams)
                    , body = Http.emptyBody
                    , decoder = Paginated.decoder Json.Decode.value
                    }
            in
            ( newStore, Just req )


handleResponse :
    Request.Msg ()
    -> Result Http.Extra.DetailedError Encode.Value
    -> Store Encode.Value
    -> Store Encode.Value
handleResponse request response store =
    let
        key =
            Request.key request
    in
    Dict.insert key (Loadable.fromResult response) store


handleResponsePaginated :
    Request.Msg Paginated.Config
    -> Result Http.Extra.DetailedError (Paginated Encode.Value)
    -> Store (Paginated Encode.Value)
    -> Store (Paginated Encode.Value)
handleResponsePaginated request response store =
    let
        key =
            Request.key request
    in
    Dict.update key
        (Maybe.map
            (\prev ->
                let
                    prevData =
                        Loadable.map .data prev
                            |> Loadable.withDefault []

                    apiDataNextPage =
                        Loadable.fromResult response
                in
                apiDataNextPage
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
    Request () a
    -> Store Encode.Value
    -> Loadable Http.Extra.DetailedError a
get request store =
    let
        key =
            Request.key (Request.msg request)

        maybeData =
            Dict.get key store
    in
    maybeData
        |> Maybe.withDefault Loadable.notAsked
        |> Loadable.andThen
            (Json.Decode.decodeValue (Request.decoder request)
                >> Result.mapError Http.Extra.BadBody
                >> Loadable.fromResult
            )


getAll :
    Request Paginated.Config a
    -> Store (Paginated Encode.Value)
    -> Loadable Http.Extra.DetailedError (List a)
getAll request store =
    let
        key =
            Request.key (Request.msg request)
    in
    Dict.get key store
        |> Maybe.withDefault Loadable.notAsked
        |> Loadable.andThen
            (.data
                >> Result.Extra.combineMap (Json.Decode.decodeValue (Request.decoder request))
                >> Result.mapError Http.Extra.BadBody
                >> Loadable.fromResult
            )
