{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Data.Morpheus.Types.Internal.Validation.SchemaValidator
  ( SchemaValidator,
    TypeSystemContext (..),
    constraintInterface,
    renderField,
    withLocalContext,
    runSchemaValidator,
    inInterface,
    inType,
    inField,
    inArgument,
    ON_INTERFACE,
    ON_TYPE,
    TypeEntity (..),
    Field (..),
    InterfaceName (..),
    PLACE,
  )
where

import Control.Monad.Except (throwError)
import Data.Morpheus.Ext.Result (GQLResult)
import Data.Morpheus.Types.Internal.AST
  ( ANY,
    CONST,
    FieldName,
    FieldsDefinition,
    Name,
    OUT,
    PropName (PropName),
    TypeContent (..),
    TypeDefinition (..),
    TypeName,
    mkBaseType,
    msg,
    unpackName,
  )
import Data.Morpheus.Types.Internal.AST.Type (TypeKind (KindObject))
import Data.Morpheus.Types.Internal.AST.TypeSystem (Schema)
import Data.Morpheus.Types.Internal.Config (Config)
import Data.Morpheus.Types.Internal.Validation (Scope (..), ScopeKind (TYPE), runValidator)
import Data.Morpheus.Types.Internal.Validation.Validator
  ( Validator (..),
    renderField,
    withContext,
    withScope,
  )
import Relude hiding (local)

inInterface ::
  TypeName ->
  SchemaValidator (TypeEntity 'ON_INTERFACE) v ->
  SchemaValidator (TypeEntity 'ON_TYPE) v
inInterface name = pushPath name . withLocalContext (\t -> t {interfaceName = OnInterface name})

inType ::
  TypeName ->
  SchemaValidator (TypeEntity 'ON_TYPE) v ->
  SchemaValidator () v
inType name = pushPath name . withLocalContext (const (TypeEntity OnType name))

inField ::
  FieldName ->
  SchemaValidator (Field p) v ->
  SchemaValidator (TypeEntity p) v
inField fieldName = pushPath fieldName . withLocalContext (Field fieldName Nothing)

inArgument ::
  FieldName ->
  SchemaValidator (Field p) v ->
  SchemaValidator (Field p) v
inArgument name = pushPath name . withLocalContext (\field -> field {fieldArgument = Just name})

data PLACE = ON_INTERFACE | ON_TYPE

type ON_INTERFACE = 'ON_INTERFACE

type ON_TYPE = 'ON_TYPE

data InterfaceName (p :: PLACE) where
  OnInterface :: TypeName -> InterfaceName 'ON_INTERFACE
  OnType :: InterfaceName 'ON_TYPE

data TypeEntity (p :: PLACE) = TypeEntity
  { interfaceName :: InterfaceName p,
    typeName :: TypeName
  }

data Field p = Field
  { fieldName :: FieldName,
    fieldArgument :: Maybe FieldName,
    fieldOf :: TypeEntity p
  }

initialScope :: Scope
initialScope =
  Scope
    { position = Nothing,
      currentTypeName = "Root",
      currentTypeKind = KindObject Nothing,
      currentTypeWrappers = mkBaseType,
      kind = TYPE,
      fieldName = "Root",
      path = []
    }

newtype TypeSystemContext c = TypeSystemContext
  {local :: c}
  deriving (Show)

pushPath :: Name t -> SchemaValidator a v -> SchemaValidator a v
pushPath name = withScope (\x -> x {path = path x <> [PropName (unpackName name)]})

withLocalContext :: (a -> b) -> SchemaValidator b v -> SchemaValidator a v
withLocalContext = withContext . updateLocal

updateLocal :: (a -> b) -> TypeSystemContext a -> TypeSystemContext b
updateLocal f ctx = ctx {local = f (local ctx)}

type SchemaValidator c = Validator CONST (TypeSystemContext c)

runSchemaValidator :: Validator s (TypeSystemContext ()) a -> Config -> Schema s -> GQLResult a
runSchemaValidator value config sysSchema =
  runValidator
    value
    config
    sysSchema
    initialScope
    TypeSystemContext
      { local = ()
      }

constraintInterface ::
  TypeDefinition ANY CONST ->
  SchemaValidator ctx (TypeName, FieldsDefinition OUT CONST)
constraintInterface
  TypeDefinition
    { typeName,
      typeContent = DataInterface fields
    } = pure (typeName, fields)
constraintInterface TypeDefinition {typeName} =
  throwError $ "type " <> msg typeName <> " must be an interface"
