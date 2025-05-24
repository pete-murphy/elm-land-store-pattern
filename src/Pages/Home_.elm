module Pages.Home_ exposing (Model, Msg, page)

import Api.Tag as Tag exposing (Tag)
import ApiData exposing (ApiData)
import Auth
import Effect exposing (Effect)
import Html
import Html.Attributes as Attributes
import Http.Extra
import Layouts
import Page exposing (Page)
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
    { tags : Data (List Tag) }


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user shared _ =
    ( { tags = ApiData.loading }
    , Effect.request (Tag.get user.credentials)
        BackendRespondedToGetTags
    )



-- UPDATE


type alias ApiResult a =
    Result Http.Extra.DetailedError a


type Msg
    = BackendRespondedToGetTags (ApiResult (List Tag))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetTags result ->
            ( { model | tags = ApiData.fromResult result }
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
        [ Html.section [ Attributes.class "flex flex-col gap-4" ]
            [ Html.h2 [ Attributes.class "text-xl font-bold" ]
                [ Html.text "Tags" ]
            , case ApiData.value model.tags of
                ApiData.Empty ->
                    Html.text "Loading..."

                ApiData.Failure error ->
                    Html.text "Error"

                ApiData.Success tags ->
                    Tag.viewList tags
            ]
        , Html.section [] []
        ]
    }
