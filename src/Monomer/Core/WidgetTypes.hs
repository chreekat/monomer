{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Monomer.Core.WidgetTypes where

import Control.Applicative ((<|>))
import Control.Lens (ALens')
import Data.Default
import Data.Map.Strict (Map)
import Data.Sequence (Seq)
import Data.String (IsString(..))
import Data.Text (Text)
import Data.Typeable (Typeable)

import Monomer.Core.BasicTypes
import Monomer.Core.StyleTypes
import Monomer.Core.ThemeTypes
import Monomer.Event.Types
import Monomer.Graphics.Types

type Timestamp = Int
type GlobalKeys s e = Map WidgetKey (WidgetNode s e)

data FocusDirection
  = FocusFwd
  | FocusBwd
  deriving (Eq, Show)

data TextOverflow
  = Ellipsis
  | ClipText
  deriving (Eq, Show)

data WindowRequest
  = WindowSetTitle Text
  | WindowSetFullScreen
  | WindowMaximize
  | WindowMinimize
  | WindowRestore
  | WindowBringToFront
  deriving (Eq, Show)

newtype WidgetType
  = WidgetType { unWidgetType :: String }
  deriving (Eq, Show)

instance IsString WidgetType where
  fromString = WidgetType

data WidgetData s a
  = WidgetValue a
  | WidgetLens (ALens' s a)

newtype WidgetKey
  = WidgetKey Text
  deriving (Eq, Ord, Show)

data WidgetState
  = forall i . Typeable i => WidgetState i

data WidgetRequest s
  = IgnoreParentEvents
  | IgnoreChildrenEvents
  | ResizeWidgets
  | MoveFocus FocusDirection
  | SetFocus Path
  | GetClipboard Path
  | SetClipboard ClipboardData
  | StartTextInput Rect
  | StopTextInput
  | SetOverlay Path
  | ResetOverlay
  | SetCursorIcon CursorIcon
  | RenderOnce
  | RenderEvery Path Int
  | RenderStop Path
  | ExitApplication Bool
  | UpdateWindow WindowRequest
  | UpdateModel (s -> s)
  | forall i . Typeable i => SendMessage Path i
  | forall i . Typeable i => RunTask Path (IO i)
  | forall i . Typeable i => RunProducer Path ((i -> IO ()) -> IO ())

data WidgetResult s e = WidgetResult {
  _wrWidget :: Maybe (Widget s e),
  _wrStyle :: Maybe Style,
  _wrChildren :: Maybe (Seq (WidgetNode s e)),
  _wrRequests :: Seq (WidgetRequest s),
  _wrEvents :: Seq e
}

instance Default (WidgetResult s e) where
  def = WidgetResult {
    _wrWidget = Nothing,
    _wrStyle = Nothing,
    _wrChildren = Nothing,
    _wrRequests = def,
    _wrEvents = def
  }

-- This instance is lawless (there is not an empty widget): use with caution
instance Semigroup (WidgetResult s e) where
  er1 <> er2 = WidgetResult {
    _wrWidget = _wrWidget er2 <|> _wrWidget er1,
    _wrChildren = _wrChildren er2 <|> _wrChildren er1,
    _wrStyle = _wrStyle er2 <|> _wrStyle er1,
    _wrRequests = _wrRequests er1 <> _wrRequests er2,
    _wrEvents = _wrEvents er1 <> _wrEvents er2
  }

data WidgetResultNode s e = WidgetResultNode {
  _wrnWidgetNode :: WidgetNode s e,
  _wrnRequests :: Seq (WidgetRequest s),
  _wrnEvents :: Seq e
}

data WidgetSizeReq s e = WidgetSizeReq {
  _wsrWidget :: WidgetNode s e,
  _wsrSizeReqW :: SizeReq,
  _wsrSizeReqH :: SizeReq
} deriving (Show)

data WidgetEnv s e = WidgetEnv {
  _weOS :: Text,
  _weRenderer :: Renderer,
  _weTheme :: Theme,
  _weAppWindowSize :: Size,
--  _weGlobalKeys :: GlobalKeys s e,
  _weFocusedPath :: Path,
  _weOverlayPath :: Maybe Path,
  _weCurrentCursor :: CursorIcon,
  _weModel :: s,
  _weInputStatus :: InputStatus,
  _weTimestamp :: Timestamp,
  _weInTopLayer :: Point -> Bool
}

data WidgetNode s e = WidgetNode {
  -- | The actual widget
  _wnWidget :: Widget s e,
  -- | Common information about the instance
  _wnWidgetInstance :: WidgetInstance,
  -- | The children widget, if any
  _wnChildren :: Seq (WidgetNode s e)
}

data Widget s e =
  Widget {
    -- | Performs widget initialization
    widgetInit
      :: WidgetEnv s e
      -> WidgetNode s e
      -> WidgetResult s e,
    -- | Merges the current widget tree with the old one
    --
    -- Current state
    -- Old instance
    -- New instance
    widgetMerge
      :: WidgetEnv s e
      -> WidgetNode s e
      -> WidgetNode s e
      -> WidgetResult s e,
    -- | Performs widget release
    widgetDispose
      :: WidgetEnv s e
      -> WidgetNode s e
      -> WidgetResult s e,
    -- | Returns the current internal state, which can later be used when
    -- | merging widget trees
    widgetGetState
      :: WidgetEnv s e
      -> Maybe WidgetState,
    -- | Returns the list of focusable paths, if any
    --
    widgetFindNextFocus
      :: WidgetEnv s e
      -> FocusDirection
      -> Path
      -> WidgetNode s e
      -> Maybe Path,
    -- | Returns the path of the child item with the given coordinates, starting
    -- | on the given path
    widgetFindByPoint
      :: WidgetEnv s e
      -> Path
      -> Point
      -> WidgetNode s e
      -> Maybe Path,
    -- | Handles an event
    --
    -- Current user state
    -- Path of focused widget
    -- Current widget path
    -- Event to handle
    --
    -- Returns: the list of generated events and, maybe, a new version of the
    -- widget if internal state changed
    widgetHandleEvent
      :: WidgetEnv s e
      -> Path
      -> SystemEvent
      -> WidgetNode s e
      -> Maybe (WidgetResult s e),
    -- | Handles a custom message
    --
    -- Result of asynchronous computation
    --
    -- Returns: the list of generated events and a new version of the widget if
    -- internal state changed
    widgetHandleMessage
      :: forall i . Typeable i
      => WidgetEnv s e
      -> Path
      -> i
      -> WidgetNode s e
      -> Maybe (WidgetResult s e),
    -- | Updates the sizeReq field for the widget
    widgetGetSizeReq
      :: WidgetEnv s e
      -> WidgetNode s e
      -> WidgetSizeReq s e,
    -- | Resizes the children of this widget
    --
    -- Vieport assigned to the widget
    -- Region assigned to the widget
    -- Style options
    -- Preferred size for each of the children widgets
    --
    -- Returns: the size assigned to each of the children
    widgetResize
      :: WidgetEnv s e
      -> Rect
      -> Rect
      -> WidgetNode s e
      -> WidgetNode s e,
    -- | Renders the widget
    --
    -- Renderer
    -- The widget instance to render
    -- The current time in milliseconds
    --
    -- Returns: unit
    widgetRender
      :: Renderer
      -> WidgetEnv s e
      -> WidgetNode s e
      -> IO ()
  }

-- | Complementary information to a Widget, forming a node in the view tree
data WidgetInstance =
  WidgetInstance {
    -- | Type of the widget
    _wiWidgetType :: !WidgetType,
    -- | Key/Identifier of the widget
    _wiKey :: Maybe WidgetKey,
    -- | The path of the instance in the widget tree
    _wiPath :: !Path,
    -- | The preferred size for the widget
    _wiSizeReqW :: SizeReq,
    _wiSizeReqH :: SizeReq,
    -- | Indicates if the widget is enabled for user interaction
    _wiEnabled :: !Bool,
    -- | Indicates if the widget is visible
    _wiVisible :: !Bool,
    -- | Indicates whether the widget can receive focus
    _wiFocusable :: !Bool,
    -- | The visible area of the screen assigned to the widget
    _wiViewport :: !Rect,
    -- | The area of the screen where the widget can draw
    -- | Usually equal to _wiViewport, but may be larger if the widget is
    -- | wrapped in a scrollable container
    _wiRenderArea :: !Rect,
    -- | Style attributes of the widget instance
    _wiStyle :: Style
  } deriving (Eq, Show)

instance Default WidgetInstance where
  def = WidgetInstance {
    _wiWidgetType = "",
    _wiKey = Nothing,
    _wiPath = rootPath,
    _wiSizeReqW = def,
    _wiSizeReqH = def,
    _wiEnabled = True,
    _wiVisible = True,
    _wiFocusable = False,
    _wiViewport = def,
    _wiRenderArea = def,
    _wiStyle = def
  }

instance Show (WidgetRequest s) where
  show IgnoreParentEvents = "IgnoreParentEvents"
  show IgnoreChildrenEvents = "IgnoreChildrenEvents"
  show ResizeWidgets = "ResizeWidgets"
  show (MoveFocus dir) = "MoveFocus: " ++ show dir
  show (SetFocus path) = "SetFocus: " ++ show path
  show (GetClipboard path) = "GetClipboard: " ++ show path
  show (SetClipboard _) = "SetClipboard"
  show (StartTextInput rect) = "StartTextInput: " ++ show rect
  show StopTextInput = "StopTextInput"
  show ResetOverlay = "ResetOverlay"
  show (SetOverlay path) = "SetOverlay: " ++ show path
  show (SetCursorIcon icon) = "SetCursorIcon: " ++ show icon
  show RenderOnce = "RenderOnce"
  show (RenderEvery path ms) = "RenderEvery: " ++ show path ++ " - " ++ show ms
  show (RenderStop path) = "RenderStop: " ++ show path
  show ExitApplication{} = "ExitApplication"
  show (UpdateWindow req) = "UpdateWindow: " ++ show req
  show UpdateModel{} = "UpdateModel"
  show SendMessage{} = "SendMessage"
  show RunTask{} = "RunTask"
  show RunProducer{} = "RunProducer"

instance Show (WidgetResult s e) where
  show result = "WidgetResult "
    ++ "{ _wrRequests: " ++ show (_wrRequests result)
    ++ ", _wrEvents: " ++ show (length (_wrEvents result))
    ++ " }"

instance Show (WidgetEnv s e) where
  show wenv = "WidgetEnv "
    ++ "{ _weOS: " ++ show (_weOS wenv)
    ++ ", _weAppWindowSize: " ++ show (_weAppWindowSize wenv)
    ++ ", _weFocusedPath: " ++ show (_weFocusedPath wenv)
    ++ ", _weTimestamp: " ++ show (_weTimestamp wenv)
    ++ " }"

instance Show (WidgetNode s e) where
  show node = "WidgetNode "
    ++ "{ _wnWidgetInstance: " ++ show (_wnWidgetInstance node)
    ++ ", _wnChildren: " ++ show (_wnChildren node)
    ++ " }"
