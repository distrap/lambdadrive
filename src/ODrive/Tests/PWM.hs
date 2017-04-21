{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards #-}

module ODrive.Tests.PWM where

import Ivory.Language
import Ivory.Tower

import Ivory.BSP.STM32.ClockConfig

import ODrive.Platforms
import ODrive.LED
import ODrive.Types
import ODrive.PWM

app :: (e -> ClockConfig)
    -> (e -> PWMOut)
    -> (e -> ColoredLEDs)
    -> Tower e ()
app _tocc totestpwm toleds = do
  odriveTowerDeps

  pwm  <- fmap totestpwm getEnv
  leds <- fmap toleds getEnv

  blink (Milliseconds 1000) [redLED leds]

  PWM{..} <- pwmTower pwm

  periodic <- period (Milliseconds 10)

  monitor "simplecontroller" $ do
    pwmout <- stateInit "pwmout" $ iarray [ival 0, ival 0, ival 0]

    handler periodic "periodic" $ do
      callbackV $ \p -> do
        let time  :: Uint64
            time  = signCast $ toIMicroseconds p

        let val = castDefault $ (time `iShiftR` 6) .% (safeCast tim_period_clocks)

        store (pwmout ! 0) val
        store (pwmout ! 1) val
        store (pwmout ! 2) (val + 2000)
        pwm_set (constRef pwmout)
        return ()
