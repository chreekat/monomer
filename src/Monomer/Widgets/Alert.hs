{-# LANGUAGE RankNTypes #-}

module Monomer.Widgets.Alert (
  alert,
  alert_
) where

import Debug.Trace

import Control.Applicative ((<|>))
import Control.Lens (Lens', (&), (^.), (^?), (.~), (?~), (<>~), non)
import Data.Default
import Data.Maybe
import Data.Text (Text)

import Monomer.Core
import Monomer.Event
import Monomer.Graphics

import Monomer.Widgets.Box
import Monomer.Widgets.Button
import Monomer.Widgets.Container
import Monomer.Widgets.Label
import Monomer.Widgets.Spacer
import Monomer.Widgets.Stack

import qualified Monomer.Lens as L

data AlertCfg = AlertCfg {
  _alcTitle :: Maybe Text,
  _alcClose :: Maybe Text
}

instance Default AlertCfg where
  def = AlertCfg {
    _alcTitle = Nothing,
    _alcClose = Nothing
  }

instance Semigroup AlertCfg where
  (<>) a1 a2 = AlertCfg {
    _alcTitle = _alcTitle a2 <|> _alcTitle a1,
    _alcClose = _alcClose a2 <|> _alcClose a1
  }

instance Monoid AlertCfg where
  mempty = def

alert :: Text -> e -> WidgetInstance s e
alert message evt = createThemed "alert" factory where
  factory wenv = alert_ wenv message evt def

-- Maybe add styles for dialog and color for inactive/empty background
alert_ :: WidgetEnv s e -> Text -> e -> AlertCfg -> WidgetInstance s e
alert_ wenv message evt config = alertBox where
  title = fromMaybe "" (_alcTitle config)
  close = fromMaybe "Close" (_alcClose config)
  emptyOverlayColor = themeEmptyOverlayColor wenv
  dismissButton = button close evt & L.style .~ themeBtnMain wenv
  alertTree = vstack [
      label title & L.style .~ themeDialogTitle wenv,
      label message & L.style .~ themeDialogBody wenv,
      box_ dismissButton [alignLeft] & L.style .~ themeDialogButtons wenv
    ] & L.style .~ themeDialogFrame wenv
  alertBox = box_ alertTree [onClickEmpty evt] & L.style .~ emptyOverlayColor
