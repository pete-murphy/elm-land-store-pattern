module Pages.Home_ exposing (Model, Msg, page)

import Api.Tag as Tag exposing (Tag)
import Api.User exposing (User)
import ApiData exposing (ApiData)
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.Extra
import Layouts
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user shared
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    ApiData Http.Extra.DetailedError a


type alias Model =
    { tags : Data (List Tag)
    , users : Data (List (User Api.User.Preview))
    }


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user shared _ =
    ( { tags = ApiData.loading
      , users = ApiData.loading
      }
    , Effect.batch
        [ Effect.request (Tag.get user.credentials)
            BackendRespondedToGetTags
        , Effect.request (Api.User.list user.credentials { page = 1, limit = 5 })
            BackendRespondedToGetUsers
        ]
    )



-- UPDATE


type alias ApiResult a =
    Result Http.Extra.DetailedError a


type Msg
    = BackendRespondedToGetTags (ApiResult (List Tag))
    | BackendRespondedToGetUsers (ApiResult (Paginated (User Api.User.Preview)))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetTags result ->
            ( { model | tags = ApiData.fromResult result }
            , Effect.none
            )

        BackendRespondedToGetUsers result ->
            ( { model | users = ApiData.fromResult (result |> Result.map .data) }
            , Effect.none
            )

        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Home"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewSection
                { title = "Tags"
                , apiData = model.tags
                , view = Tag.viewList
                }
            , viewSection
                { title = "Users"
                , apiData = model.users
                , view = Api.User.viewPreviewList
                }
            ]
        ]
    }


viewSection : { title : String, apiData : Data a, view : a -> Html msg } -> Html msg
viewSection props =
    Html.section [ Attributes.class "flex flex-col gap-4" ]
        [ Html.h2 [ Attributes.class "text-xl font-bold" ]
            [ Html.text props.title ]
        , case ApiData.value props.apiData of
            ApiData.Empty ->
                viewSkeletonSectionContent

            ApiData.Failure error ->
                -- TODO: Show error
                Html.text (Debug.toString error)

            ApiData.Success value ->
                props.view value
        ]


viewSkeletonSectionContent : Html msg
viewSkeletonSectionContent =
    Html.div [ Attributes.class "flex flex-col gap-4 bg-gray-100 p-4 rounded-md min-h-40" ]
        []
