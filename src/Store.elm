module Store exposing (..)

-- import Store.Request as Request exposing (Key, Request)

import Dict exposing (Dict)
import Http
import Http.DetailedError as DetailedError exposing (DetailedError)
import Http.Extra exposing (Request)
import Json.Decode
import Json.Encode as Encode
import Loadable exposing (Loadable)
import Paginated exposing (Paginated)
import Url.Builder


type alias Store a =
    Dict String (Loadable DetailedError a)


type alias Msg =
    { url : String
    , headers : List Http.Header
    }


handleRequest :
    Strategy
    -> Msg
    -> Store Encode.Value
    -> ( Store Encode.Value, Maybe (Request Encode.Value) )
handleRequest strategy request store =
    let
        key =
            request.url

        newStoreUpdate =
            Dict.update key
                (Maybe.map Loadable.toLoading
                    >> Maybe.withDefault Loadable.loading
                    >> Just
                )
                store

        newStoreInsert =
            Dict.insert key Loadable.loading store

        req : Request Encode.Value
        req =
            { method = "GET"
            , headers = request.headers
            , url = request.url
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
    -> Msg
    -> Store (Paginated Encode.Value)
    -> ( Store (Paginated Encode.Value), Maybe (Request (Paginated Encode.Value)) )
handleRequestPaginated strategy request store =
    let
        key =
            request.url

        lastFetched =
            Dict.get key store
                |> Maybe.andThen Loadable.toMaybe

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
                newStore : Store (Paginated Encode.Value)
                newStore =
                    Dict.update key
                        (Maybe.map Loadable.toLoading
                            >> Maybe.withDefault Loadable.loading
                            >> Just
                        )
                        store

                req : Request (Paginated Encode.Value)
                req =
                    { method = "GET"
                    , headers = request.headers
                    , url =
                        let
                            p =
                                String.dropLeft 1 (Url.Builder.toQuery paginationParams)
                        in
                        -- HACK
                        if String.contains "?" request.url then
                            request.url ++ "&" ++ p

                        else
                            request.url ++ "?" ++ p
                    , body = Http.emptyBody
                    , decoder = Paginated.decoder Json.Decode.value
                    }
            in
            ( newStore, Just req )


handleResponse :
    Msg
    -> Result DetailedError Encode.Value
    -> Store Encode.Value
    -> Store Encode.Value
handleResponse request response store =
    let
        key =
            request.url
    in
    Dict.insert key (Loadable.fromResult response) store


handleResponsePaginated :
    Msg
    -> Result DetailedError (Paginated Encode.Value)
    -> Store (Paginated Encode.Value)
    -> Store (Paginated Encode.Value)
handleResponsePaginated request response store =
    let
        key =
            request.url
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
    Request a
    -> Store Encode.Value
    -> Loadable DetailedError a
get request store =
    let
        url =
            request.url

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


getAll :
    Request (Paginated a)
    -> Store (Paginated Encode.Value)
    -> Loadable DetailedError (List a)
getAll request store =
    let
        url =
            request.url
    in
    Dict.get url store
        |> Maybe.withDefault Loadable.notAsked
        |> Loadable.andThen
            (Paginated.encode {- TODOn't -} identity
                >> Json.Decode.decodeValue request.decoder
                >> Result.mapError DetailedError.BadBody
                >> Loadable.fromResult
            )
        |> Loadable.map .data
