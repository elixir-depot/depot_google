defmodule DepotGoogleTest do
  use ExUnit.Case
  import Depot.AdapterTest

  adapter_test %{config: config} do
    filesystem = DepotGoogle.configure(config: config, bucket: "default")
    {:ok, filesystem: filesystem}
  end
end
