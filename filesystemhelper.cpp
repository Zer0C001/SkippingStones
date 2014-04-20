/*
 * Copyright 2014 Ruediger Gad
 *
 * This file is part of SkippingStones.
 *
 * SkippingStones is largely based on libpebble by Liam McLoughlin
 * https://github.com/Hexxeh/libpebble
 *
 * SkippingStones is published under the same license as libpebble (as of 10-02-2014):
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#include "filesystemhelper.h"

#include <QDir>
#include <QFile>
#include <QProcess>

FileSystemHelper::FileSystemHelper(QObject *parent) :
    QObject(parent)
{
    QDir dir;
    dir.mkpath(QDir::homePath() + "/skippingStones/pbw");
    dir.mkpath(QDir::homePath() + "/.skippingStones/pbw_tmp");
}

QStringList FileSystemHelper::getFiles(QString dir, QString filter) {
    QDir d(dir);

    QStringList nameFilters;
    nameFilters.append(filter);

    d.setFilter(QDir::Files);
    d.setNameFilters(nameFilters);
    d.setSorting(QDir::Name);

    return d.entryList();
}

QString FileSystemHelper::getHomePath() {
    return QDir::homePath();
}

QString FileSystemHelper::readHex(const QString &fileName) {
    QFile f(fileName);
    if (! f.open(QFile::ReadOnly)) {
        return "";
    }
    return QString(f.readAll().toHex());
}

void FileSystemHelper::unzip(QString source, QString destination) {
    QProcess process;
    process.start("unzip -o " + source + " -d " + destination);
    process.waitForFinished();
}
