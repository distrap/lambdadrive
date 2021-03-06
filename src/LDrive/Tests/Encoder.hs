{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RankNTypes #-}

module LDrive.Tests.Encoder where

import Ivory.Language
import Ivory.Language.Cast
import Ivory.Tower

import Ivory.BSP.STM32.ClockConfig
import Ivory.BSP.STM32.Driver.UART

import LDrive.Encoder
import LDrive.Platforms
import LDrive.LED
import LDrive.Types
import LDrive.Serialize
import LDrive.Ivory.Types.Encoder

app :: (e -> ClockConfig)
    -> (e -> Enc)
    -> (e -> TestUART)
    -> (e -> ColoredLEDs)
    -> Tower e ()
app tocc totestenc touart toleds = do
  ldriveTowerDeps

  cc <- fmap tocc getEnv
  enc  <- fmap totestenc getEnv
  leds <- fmap toleds getEnv
  uart <- fmap touart getEnv

  blink (Milliseconds 1000) [redLED leds]
  blink (Milliseconds 666) [greenLED leds]

  (uarto, _istream, mon) <- uartTower tocc (testUARTPeriph uart) (testUARTPins uart) 115200

  monitor "uart" mon

  Encoder{..} <- encoderTower enc

  periodic <- period (Milliseconds 10)

  encchan <- channel

  -- 2400 pulses per mechanical revolution
  let encoderCpr = 600*4 :: Sint32
      motorPoles = 7 :: Uint8
      bandwidth = 2000 :: IFloat
      kp = bandwidth * 2
      ki = (1/4 * kp ** 2) -- critically damped

  monitor "encoder" $ do
    lastSample <- state "lastSample"

    encState <- state "encState"

    handler systemInit "init" $ do
      callback $ const $ do
        encoderInitState motorPoles encoderCpr (currentMeasPeriod cc) kp ki encState

        -- check that we don't get problems with discrete time approximation
        assert ((currentMeasPeriod cc) * kp <? 1.0)

    handler periodic "encCvt" $ do
      e <- emitter (fst encchan) 1
      callback $ const $ do

        sample <- encoder_get encState

        refCopy lastSample sample
        emit e sample

  monitor "encoderSender" $ do
    encoderSender (snd encchan) uarto
