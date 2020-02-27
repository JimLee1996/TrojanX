#!/bin/sh

#  install_privoxy.sh
#  ShadowsocksX-NG
#
#  Created by 王晨 on 16/10/7.
#  Copyright © 2016年 zhfish. All rights reserved.


cd `dirname "${BASH_SOURCE[0]}"`

NGDir="$HOME/Library/Application Support/TrojanX/"
echo ngdir: ${NGDir}

mkdir -p "$NGDir"
cp -f privoxy "$NGDir"

echo done
